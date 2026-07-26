#ifndef IP_GEOLOCATION_HH
#define IP_GEOLOCATION_HH

#include "weather_data.hh"

#include <string>

// I discovered the "forward declaration", it's way better than `#include "http_request.hh"`,
// It avoids pulling all of http_request.hh, libwebsockets declarations, etc.
// into every file that happens to include ip_geolocation.hh.
class http_client;

bool get_ip_geolocation(http_client *http, weather_location *location, std::string *error_message);

#endif

