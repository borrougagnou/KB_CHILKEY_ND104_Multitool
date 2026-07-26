#ifndef IP_GEOLOCATION_HH
#define IP_GEOLOCATION_HH

#include "weather_data.hh"

#include <string>

bool get_ip_geolocation(weather_location *location, std::string *error_message);

#endif

