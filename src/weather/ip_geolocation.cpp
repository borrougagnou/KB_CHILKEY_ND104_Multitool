#include "include/ip_geolocation.hh"

#include "include/http_request.hh"
#include "../external/json/json.hpp"

#include <cmath>
#include <sstream>
#include <string>


static const char ip_geolocation_url[] = "http://ip-api.com/json/?fields=status,message,country,city,lat,lon";

bool get_ip_geolocation(http_client *http, weather_location *location, std::string *error_message)
{
    http_response      response;
    nlohmann::json     parsed_response;
    std::ostringstream message;
    std::string        request_url;
    std::string        status;
    double             latitude;
    double             longitude;

    if (!http || !location || !error_message)
        return false;

    request_url = ip_geolocation_url;

    if (!get_http_response(http, &request_url, &response, error_message))
        return false;

    if (response.status_code < 200u || response.status_code >= 300u)
    {
        message << "IP geolocation returned HTTP " << response.status_code;
        *error_message = message.str();
        return false;
    }

    try
    {
        parsed_response = nlohmann::json::parse(response.body);
    }
    catch (const nlohmann::json::exception &exception)
    {
        *error_message = std::string("Invalid JSON returned by IP geolocation: ") + exception.what();
        return false;
    }

    if (!parsed_response.is_object()
        || !parsed_response.contains("status")
        || !parsed_response["status"].is_string())
    {
        *error_message = "IP geolocation response does not contain a valid status";
        return false;
    }

    status = parsed_response["status"].get<std::string>();

    if (status != "success")
    {
        if (parsed_response.contains("message") && parsed_response["message"].is_string())
            *error_message = "IP geolocation failed: " + parsed_response["message"].get<std::string>();
        else
            *error_message = "IP geolocation failed without an error message";

        return false;
    }

    if (!parsed_response.contains("lat")
        || !parsed_response["lat"].is_number()
        || !parsed_response.contains("lon")
        || !parsed_response["lon"].is_number())
    {
        *error_message = "IP geolocation response does not contain valid coordinates";
        return false;
    }

    latitude  = parsed_response["lat"].get<double>();
    longitude = parsed_response["lon"].get<double>();

    if (!std::isfinite(latitude) || latitude < -90.0 || latitude > 90.0 ||
        !std::isfinite(longitude) || longitude < -180.0 || longitude > 180.0)
    {
        *error_message = "IP geolocation returned coordinates outside valid ranges";
        return false;
    }

    location->city.clear();
    location->country.clear();

    if (parsed_response.contains("city") && parsed_response["city"].is_string())
        location->city = parsed_response["city"].get<std::string>();

    if (parsed_response.contains("country") && parsed_response["country"].is_string())
        location->country = parsed_response["country"].get<std::string>();

    location->latitude  = latitude;
    location->longitude = longitude;

    return true;
}
