#ifndef MELETRIX_HH
#define MELETRIX_HH

#include "../weather_data.hh"

#include <string>


class http_client;


bool get_meletrix_weather(
    http_client            *http,
    const weather_location *location,
    temperature_unit       unit,
    weather_data           *weather,
    std::string            *error_message
);

#endif

