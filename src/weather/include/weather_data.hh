#ifndef WEATHER_DATA_HH
#define WEATHER_DATA_HH

#include <cstdint>
#include <string>

static const char weather_configuration_directory[] = "Chilkey_ND104";

enum weather_icon : std::uint8_t {
    weather_sunny          = 0x00,
    weather_heavy_clouds   = 0x01, // same
    weather_overcast       = 0x01, // same
    weather_partly_cloudy  = 0x02,
    weather_cloudy         = 0x03,
    weather_rain           = 0x04,
    weather_snow           = 0x05,
    weather_clear_night    = 0x06,
    weather_cloudy_night   = 0x07,
    weather_fog            = 0x08,
    weather_thunderstorm   = 0x09
};

enum temperature_unit {
    temperature_celsius,
    temperature_fahrenheit
};

enum weather_provider {
    weather_provider_open_meteo,
    weather_provider_meletrix
};

struct weather_data {
    weather_icon icon;
    std::int16_t current_temperature;
    std::int16_t maximum_temperature;
    std::int16_t minimum_temperature;
};

struct weather_location {
    std::string city;
    std::string country;
    double      latitude;
    double      longitude;
};

#endif

