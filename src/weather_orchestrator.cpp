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
            log_weather_error("Unable to send data on the keyboard");

        return false;
    }

    // Now we will load the http (http_request.cpp)
    operation_succeeded = initialize_http(&error_message);
    if (!operation_succeeded)
    {
        log_message = "Unable to initialize HTTP support: " + error_message;
        log_weather_error(log_message.c_str());
        return false;
    }

    operation_succeeded = resolve_weather_location(&configuration, &location, &error_message);
    if (!operation_succeeded)
    {
        cleanup_http();
        log_message = "Unable to resolve the weather location: " + error_message;
        log_weather_error(log_message.c_str());
        return false;
    }

    // do we have other weather provider ?
    // add them here
    switch (configuration.provider)
    {
        case weather_provider_open_meteo:
            operation_succeeded = get_open_meteo_weather(&location, configuration.unit, &weather, &error_message);
            break;

        default:
            error_message = "The selected weather provider is not implemented";
            operation_succeeded = false;
            break;
    }

    cleanup_http();

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

