#include "include/ip_geolocation.hh"

#include "include/http_request.hh"
#include "external/json/json.hpp"

#include <cmath>
#include <sstream>
#include <string>


static const char ip_geolocation_url[] = "http://ip-api.com/json/?fields=status,message,country,city,lat,lon";

bool get_ip_geolocation(weather_location *location, std::string *error_message)
{
    http_response        response;
    const nlohmann::json *response_json;
    nlohmann::json       parsed_response;
    std::ostringstream   message;
    std::string          request_url;
    std::string          status;
    double               latitude;
    double               longitude;

    if (!location || !error_message)
        return false;

    request_url = ip_geolocation_url;

    if (!get_http_response(&request_url, &response, error_message))
        return false;

    if (response.status_code < 200 || response.status_code >= 300)
    {
        message << "IP geolocation returned HTTP " << response.status_code;
        *error_message = message.str();
        return false;
    }

    try
    {
        parsed_response = nlohmann::json::parse(response.body);
    }
    catch (const nlohmann::json::exception& exception)
    {
        *error_message = std::string("Invalid JSON returned by IP geolocation: ") + exception.what();
        return false;
    }

    response_json = &parsed_response;

    if (!response_json->is_object() ||
        !response_json->contains("status") ||
        !(*response_json)["status"].is_string())
    {
        *error_message = "IP geolocation response does not contain a valid status";
        return false;
    }

    status = (*response_json)["status"].get<std::string>();
    if (status != "success")
    {
        if (response_json->contains("message") && (*response_json)["message"].is_string())
            *error_message = "IP geolocation failed: " + (*response_json)["message"].get<std::string>();
        else
            *error_message = "IP geolocation failed without an error message";

        return false;
    }

    if (!response_json->contains("lat") ||
        !(*response_json)["lat"].is_number() ||
        !response_json->contains("lon") ||
        !(*response_json)["lon"].is_number())
    {
        *error_message = "IP geolocation response does not contain valid coordinates";
        return false;
    }

    latitude = (*response_json)["lat"].get<double>();
    longitude = (*response_json)["lon"].get<double>();

    if (!std::isfinite(latitude) || latitude < -90.0 || latitude > 90.0 ||
        !std::isfinite(longitude) || longitude < -180.0 || longitude > 180.0)
    {
        *error_message = "IP geolocation returned coordinates outside valid ranges";
        return false;
    }

    location->city.clear();
    location->country.clear();

    if (response_json->contains("city") && (*response_json)["city"].is_string())
        location->city = (*response_json)["city"].get<std::string>();

    if (response_json->contains("country") && (*response_json)["country"].is_string())
        location->country = (*response_json)["country"].get<std::string>();

    location->latitude = latitude;
    location->longitude = longitude;

    return true;
}

