#ifndef WEATHER_CONFIG_JSON_HH
#define WEATHER_CONFIG_JSON_HH

#include "weather_data.hh"

#include <cstdint>
#include <string>


struct weather_configuration {
    weather_location information;
    temperature_unit unit;
    weather_provider provider;
    std::uint32_t    periodic_run_seconds;
    bool             use_geolocation;
};

bool load_weather_configuration(weather_configuration *configuration, std::string *error_message);

#endif

