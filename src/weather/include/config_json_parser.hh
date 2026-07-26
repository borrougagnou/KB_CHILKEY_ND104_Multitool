#ifndef CONFIG_JSON_PARSER_HH
#define CONFIG_JSON_PARSER_HH

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

bool load_weather_configuration(const std::string *configuration_path, weather_configuration *configuration, std::string *error_message);

#endif

