#ifndef OPEN_METEO_HH
#define OPEN_METEO_HH

#include "../weather_data.hh"

#include <string>


class http_client;


bool get_open_meteo_weather(
    http_client            *http,
    const weather_location *location,
    temperature_unit       unit,
    weather_data           *weather,
    std::string            *error_message
);

#endif

