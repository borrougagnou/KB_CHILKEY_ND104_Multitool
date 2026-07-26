#include "../include/weather_sources/open_meteo.hh"

#include "../include/http_request.hh"

#include "../../external/json/json.hpp"

#include <cmath>
#include <cstdint>
#include <iomanip>
#include <limits>
#include <sstream>
#include <string>


static const char open_meteo_url[] = "https://api.open-meteo.com/v1/forecast";


static weather_icon get_open_meteo_icon(int weather_code, bool is_day)
{
    weather_icon icon;

    icon = weather_sunny;

    if (weather_code == 0)
    {
        if (is_day)
            icon = weather_sunny;
        else
            icon = weather_clear_night;
    }
    else if (weather_code == 1)
    {
        if (is_day)
            icon = weather_partly_cloudy;
        else
            icon = weather_cloudy_night;
    }
    else if (weather_code == 2)
    {
        if (is_day)
            icon = weather_cloudy;
        else
            icon = weather_cloudy_night;
    }
    else if (weather_code == 3)
        icon = weather_overcast;
    else if (weather_code == 45 || weather_code == 48)
        icon = weather_fog;
    else if ((weather_code >= 51 && weather_code <= 67) || (weather_code >= 80 && weather_code <= 82))
        icon = weather_rain;
    else if ((weather_code >= 71 && weather_code <= 77) || weather_code == 85 || weather_code == 86)
        icon = weather_snow;
    else if (weather_code == 95 || weather_code == 96 || weather_code == 99)
        icon = weather_thunderstorm;

    return icon;
}


static bool convert_temperature(double temperature, std::int16_t *converted_temperature)
{
    double scaled_temperature;

    if (!converted_temperature || !std::isfinite(temperature))
        return false;

    scaled_temperature = std::round(temperature * 10.0);

    if (scaled_temperature < static_cast<double>(std::numeric_limits<std::int16_t>::min())
     || scaled_temperature > static_cast<double>(std::numeric_limits<std::int16_t>::max()))
        return false;

    *converted_temperature = static_cast<std::int16_t>(scaled_temperature);

    return true;
}


bool get_open_meteo_weather(http_client *http, const weather_location *location,
                            temperature_unit unit, weather_data *weather, std::string *error_message)
{
    http_response      response;
    nlohmann::json     parsed_response;
    nlohmann::json     current;
    nlohmann::json     daily;
    std::ostringstream request;
    std::ostringstream message;
    std::string        request_url;
    std::string        temperature_unit_name;
    double             current_temperature;
    double             maximum_temperature;
    double             minimum_temperature;
    int                weather_code;
    int                is_day;

    if (!http || !location || !weather || !error_message)
        return false;

    if (!std::isfinite(location->latitude) || location->latitude < -90.0 || location->latitude > 90.0
      || !std::isfinite(location->longitude) || location->longitude < -180.0 || location->longitude > 180.0)
    {
        *error_message = "Open-Meteo received invalid coordinates";
        return false;
    }

    if (unit == temperature_celsius)
        temperature_unit_name = "celsius";
    else if (unit == temperature_fahrenheit)
        temperature_unit_name = "fahrenheit";
    else
    {
        *error_message = "Open-Meteo received an unsupported temperature unit";
        return false;
    }

    request
        << open_meteo_url
        << "?latitude="  << std::setprecision(10) << location->latitude
        << "&longitude=" << std::setprecision(10) << location->longitude
        << "&current=temperature_2m,weather_code,is_day"
        << "&daily=temperature_2m_max,temperature_2m_min"
        << "&temperature_unit=" << temperature_unit_name
        << "&timezone=auto"
        << "&forecast_days=1";

    request_url = request.str();

    if (!get_http_response(http, &request_url, &response, error_message))
        return false;

    if (response.status_code < 200u || response.status_code >= 300u)
    {
        message << "Open-Meteo returned HTTP " << response.status_code;
        *error_message = message.str();
        return false;
    }

    try
    {
        parsed_response = nlohmann::json::parse(response.body);
    }
    catch (const nlohmann::json::exception &exception)
    {
        *error_message = std::string("Invalid JSON returned by Open-Meteo: ") + exception.what();
        return false;
    }

    if (!parsed_response.is_object())
    {
        *error_message = "Open-Meteo returned an invalid response";
        return false;
    }

    if (parsed_response.contains("error")
        && parsed_response["error"].is_boolean()
        && parsed_response["error"].get<bool>())
    {
        if (parsed_response.contains("reason") && parsed_response["reason"].is_string())
            *error_message = "Open-Meteo failed: " + parsed_response["reason"].get<std::string>();
        else
            *error_message = "Open-Meteo failed without an error message";

        return false;
    }

    if (!parsed_response.contains("current") || !parsed_response["current"].is_object())
    {
        *error_message = "Open-Meteo response does not contain current weather";
        return false;
    }

    if (!parsed_response.contains("daily") || !parsed_response["daily"].is_object())
    {
        *error_message = "Open-Meteo response does not contain daily weather";
        return false;
    }

    current = parsed_response["current"];
    daily   = parsed_response["daily"];

    if (!current.contains("temperature_2m")
      || !current["temperature_2m"].is_number()
      || !current.contains("weather_code")
      || !current["weather_code"].is_number_integer()
      || !current.contains("is_day")
      || !current["is_day"].is_number_integer())
    {
        *error_message = "Open-Meteo response does not contain valid current weather data";
        return false;
    }

    if (!daily.contains("temperature_2m_max")
      || !daily["temperature_2m_max"].is_array()
      || daily["temperature_2m_max"].empty()
      || !daily["temperature_2m_max"][0].is_number()
      || !daily.contains("temperature_2m_min")
      || !daily["temperature_2m_min"].is_array()
      || daily["temperature_2m_min"].empty()
      || !daily["temperature_2m_min"][0].is_number())
    {
        *error_message = "Open-Meteo response does not contain valid daily temperatures";
        return false;
    }

    current_temperature = current["temperature_2m"].get<double>();
    maximum_temperature = daily["temperature_2m_max"][0].get<double>();
    minimum_temperature = daily["temperature_2m_min"][0].get<double>();
    weather_code        = current["weather_code"].get<int>();
    is_day              = current["is_day"].get<int>();

    if (is_day != 0 && is_day != 1)
    {
        *error_message = "Open-Meteo returned an invalid is_day value";
        return false;
    }

    if (!convert_temperature(current_temperature,  &weather->current_temperature)
      || !convert_temperature(maximum_temperature, &weather->maximum_temperature)
      || !convert_temperature(minimum_temperature, &weather->minimum_temperature))
    {
        *error_message = "Open-Meteo returned an invalid temperature";
        return false;
    }

    weather->icon = get_open_meteo_icon(weather_code, is_day == 1);
    return true;
}
