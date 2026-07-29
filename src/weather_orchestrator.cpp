#include "include/weather_orchestrator.hh"

#include "include/http_request.hh"
#include "include/weather_data.hh"

#include "include/weather_config_json.hh"
#include "include/weather_hid_protocol.hh"
#include "include/weather_location.hh"

#include "include/weather_log.hh"

#include "include/weather_api/open_meteo.hh"

#include <string>


bool update_weather(hid_device* handle)
{
    weather_configuration configuration;
    weather_location      location;
    weather_data          weather;
    http_client           http;
    std::string           error_message;
    std::string           log_message;
    bool                  operation_succeeded;

    // Load the JSON file and his conf (weather_config_json.cpp)
    operation_succeeded = load_weather_configuration(&configuration, &error_message);
    if (!operation_succeeded)
    {
        log_message = "Invalid weather configuration: " + error_message;
        log_weather_error(log_message.c_str());

        weather.icon = weather_sunny;
        weather.current_temperature = 0;
        weather.maximum_temperature = 0;
        weather.minimum_temperature = 0;

        if (!send_weather(handle, &weather))
            log_weather_error("Unable to send the invalid-configuration data to the keyboard");

        return false;
    }

    if (configuration.use_geolocation)
        operation_succeeded = get_ip_geolocation(&http, &location, &error_message);
    else
    {
        location.city      = configuration.information.city;
        location.country   = configuration.information.country;
        location.latitude  = configuration.information.latitude;
        location.longitude = configuration.information.longitude;

        operation_succeeded = true;
    }

    if (!operation_succeeded)
    {
        log_message = "Unable to resolve the weather location: " + error_message;
        log_weather_error(log_message.c_str());
        return false;
    }

    // weather provider will be called here using a "function-pointer registry"
    operation_succeeded = configuration.provider(&http, &location, configuration.unit, &weather, &error_message);

    if (!operation_succeeded)
    {
        log_message = "Unable to obtain weather information: " + error_message;
        log_weather_error(log_message.c_str());
        return false;
    }

    if (!send_weather(handle, &weather))
    {
        log_weather_error("Unable to send weather information to the keyboard");
        return false;
    }

    return true;
}

