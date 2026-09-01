#include "include/weather_orchestrator.hh"

#include "include/weather_data.hh"

#include "include/config_file_path_discovery.hh"
#include "include/config_json_parser.hh"
#include "include/http_request.hh"
#include "include/ip_geolocation.hh"
#include "include/hid_protocol_for_weather.hh"

#include "include/weather_sources/open_meteo.hh"
#include "include/weather_sources/meletrix.hh"

#include <iostream>
#include <string>


bool update_weather(hid_device *handle)
{
    config_paths          paths;
    weather_configuration configuration;
    http_client           *http;
    weather_location      location;
    weather_data          weather;
    weather_data          invalid_weather;
    std::string           error_message;
    bool                  operation_succeeded;

    if (!handle)
        return false;

    // Default value in case there's a problem
    invalid_weather.icon                = weather_sunny;
    invalid_weather.current_temperature = 0;
    invalid_weather.maximum_temperature = 0;
    invalid_weather.minimum_temperature = 0;


    // Find the HOME USER configuration path
    operation_succeeded = get_config_path(weather_configuration_directory, &paths, &error_message);
    if (!operation_succeeded)
    {
        std::cerr << "ERROR: " << error_message << std::endl;
        send_weather(handle, &invalid_weather);

        return false;
    }

    // Read the JSON and validate the weather configuration.
    operation_succeeded = load_weather_configuration(&paths.configuration, &configuration, &error_message);
    if (!operation_succeeded)
    {
        std::cerr << "ERROR: " << error_message << std::endl;
        send_weather(handle, &invalid_weather);

        return false;
    }

    // Create one libwebsockets context (used by the geolocation and the weather source request)
    http = create_http_client(&paths.ca_certificate, &error_message);
    if (!http)
    {
        std::cerr << "ERROR: " << error_message << std::endl;

        return false;
    }

    // Resolve the location by using the JSON value or geolocation
    if (configuration.use_geolocation)
    {
        operation_succeeded = get_ip_geolocation(http, &location, &error_message);
        if (!operation_succeeded)
        {
            std::cerr << "ERROR: " << error_message << std::endl;
            destroy_http_client(http);

            return false;
        }
    }
    else
    {
        location.city      = configuration.information.city;
        location.country   = configuration.information.country;
        location.latitude  = configuration.information.latitude;
        location.longitude = configuration.information.longitude;
    }

    // Get weather data from the configured source
    operation_succeeded = false;
    if (configuration.provider == weather_provider_open_meteo)
        operation_succeeded = get_open_meteo_weather(http, &location, configuration.unit, &weather, &error_message);
    else if (configuration.provider == weather_provider_meletrix)
        operation_succeeded = get_meletrix_weather(http, &location, configuration.unit, &weather, &error_message);
    else
        error_message = "Unsupported weather source";

    destroy_http_client(http);

    // When a network or remote weather source fail
    // DO NOT OVERWRITE the weather currently displayed by the keyboard !
    // Keep the previous value til the update
    if (!operation_succeeded)
    {
        std::cerr << "ERROR: " << error_message << std::endl;

        return false;
    }

    // Display the weather information that will be sent to the keyboard
    std::cout << "Weather information:" << std::endl
              << "    Icon: "                << static_cast<unsigned int>(weather.icon)                 << std::endl
              << "    Current temperature: " << static_cast<double>(weather.current_temperature) / 10.0 << std::endl
              << "    Maximum temperature: " << static_cast<double>(weather.maximum_temperature) / 10.0 << std::endl
              << "    Minimum temperature: " << static_cast<double>(weather.minimum_temperature) / 10.0 << std::endl;
 
    //return true;

    // Send the new weather data to the keyboard
    if (!send_weather(handle, &weather))
    {
        std::cerr << "ERROR: Unable to send weather information to the keyboard" << std::endl;
        return false;
    }

    return true;
}

