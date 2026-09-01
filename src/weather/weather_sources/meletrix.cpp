#include "../include/weather_sources/meletrix.hh"

#include "../include/http_request.hh"

#include "../../external/json/json.hpp"

#include <cmath>
#include <cstdint>
#include <iomanip>
#include <limits>
#include <sstream>
#include <string>


static const char meletrix_url[] = "https://weather.meletrix.cn/v1/forecast.json";


static weather_icon get_meletrix_icon(int weather_code, bool is_day)
{
    weather_icon icon;

    icon = weather_sunny;

    if (weather_code == 1000)
    {
        if (is_day)
            icon = weather_sunny;
        else
            icon = weather_clear_night;
    }
    else if (weather_code == 1003)
    {
        if (is_day)
            icon = weather_partly_cloudy;
        else
            icon = weather_cloudy_night;
    }
    else if (weather_code == 1006)
    {
        if (is_day)
            icon = weather_cloudy;
        else
            icon = weather_cloudy_night;
    }
    else if (weather_code == 1009)
        icon = weather_overcast;
    else if ((weather_code >= 1012 && weather_code <= 1048)
      || weather_code == 1030 || weather_code == 1135 || weather_code == 1147)
        icon = weather_fog;
    else if (weather_code == 1063 || weather_code == 1072
      || (weather_code >= 1150 && weather_code <= 1201) || (weather_code >= 1240 && weather_code <= 1246))
        icon = weather_rain;
    else if (weather_code == 1066 || weather_code == 1069 || weather_code == 1114 || weather_code == 1117
      || weather_code == 1204 || weather_code == 1207
      || (weather_code >= 1210 && weather_code <= 1237) || (weather_code >= 1249 && weather_code <= 1264))
        icon = weather_snow;
    else if (weather_code == 1087 || (weather_code >= 1273 && weather_code <= 1282))
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


bool get_meletrix_weather(http_client *http, const weather_location *location,
                          temperature_unit unit, weather_data *weather, std::string *error_message)
{
    nlohmann::json     current;
    int                weather_code;
    int                is_day;
    nlohmann::json     forecast_day;
    nlohmann::json     day;
    std::ostringstream request;
    http_response      response;
    nlohmann::json     parsed_response;
    std::ostringstream message;
    std::string        request_url;
    const char         *current_temperature_name;
    double             current_temperature;
    const char         *maximum_temperature_name;
    double             maximum_temperature;
    const char         *minimum_temperature_name;
    double             minimum_temperature;


    if (!http || !location || !weather || !error_message)
        return false;

    if (!std::isfinite(location->latitude) || location->latitude < -90.0 || location->latitude > 90.0
      || !std::isfinite(location->longitude) || location->longitude < -180.0 || location->longitude > 180.0)
    {
        *error_message = "Meletrix received invalid coordinates";
        return false;
    }

    if (unit == temperature_celsius)
    {
        current_temperature_name = "temp_c";
        maximum_temperature_name = "maxtemp_c";
        minimum_temperature_name = "mintemp_c";
    }
    else if (unit == temperature_fahrenheit)
    {
        current_temperature_name = "temp_f";
        maximum_temperature_name = "maxtemp_f";
        minimum_temperature_name = "mintemp_f";
    }
    else
    {
        *error_message = "Meletrix received an unsupported temperature unit";
        return false;
    }

    request << meletrix_url << "?q="
        << std::setprecision(10) << location->latitude << ","
        << std::setprecision(10) << location->longitude;

    request_url = request.str();

    if (!get_http_response(http, &request_url, &response, error_message))
        return false;

    if (response.status_code < 200u || response.status_code >= 300u)
    {
        message << "Meletrix returned HTTP " << response.status_code;
        *error_message = message.str();
        return false;
    }

    try
    {
        parsed_response = nlohmann::json::parse(response.body);
    }
    catch (const nlohmann::json::exception &exception)
    {
        *error_message = std::string("Invalid JSON returned by Meletrix: ") + exception.what();
        return false;
    }

    if (!parsed_response.is_object())
    {
        *error_message = "Meletrix returned an invalid response";
        return false;
    }

    if (parsed_response.contains("error") && parsed_response["error"].is_object())
    {
        if (parsed_response["error"].contains("message") && parsed_response["error"]["message"].is_string())
            *error_message = "Meletrix failed: " + parsed_response["error"]["message"].get<std::string>();
        else
            *error_message = "Meletrix failed without an error message";

        return false;
    }

    if (!parsed_response.contains("current") || !parsed_response["current"].is_object())
    {
        *error_message = "Meletrix response does not contain current weather";
        return false;
    }

    if (!parsed_response.contains("forecast")
      || !parsed_response["forecast"].is_object()
      || !parsed_response["forecast"].contains("forecastday")
      || !parsed_response["forecast"]["forecastday"].is_array()
      || parsed_response["forecast"]["forecastday"].empty()
      || !parsed_response["forecast"]["forecastday"][0].is_object())
    {
        *error_message = "Meletrix response does not contain forecast weather";
        return false;
    }

    current      = parsed_response["current"];
    forecast_day = parsed_response["forecast"]["forecastday"][0];

    if (!forecast_day.contains("day") || !forecast_day["day"].is_object())
    {
        *error_message = "Meletrix response does not contain daily weather";
        return false;
    }

    day = forecast_day["day"];

    if (!current.contains(current_temperature_name)
      || !current[current_temperature_name].is_number()
      || !current.contains("is_day")
      || !current["is_day"].is_number_integer()
      || !current.contains("condition")
      || !current["condition"].is_object()
      || !current["condition"].contains("code")
      || !current["condition"]["code"].is_number_integer())
    {
        *error_message = "Meletrix response does not contain valid current weather data";
        return false;
    }

    if (!day.contains(maximum_temperature_name) || !day[maximum_temperature_name].is_number()
      || !day.contains(minimum_temperature_name) || !day[minimum_temperature_name].is_number())
    {
        *error_message = "Meletrix response does not contain valid daily temperatures";
        return false;
    }

    current_temperature = current[current_temperature_name].get<double>();
    maximum_temperature = day[maximum_temperature_name].get<double>();
    minimum_temperature = day[minimum_temperature_name].get<double>();
    weather_code        = current["condition"]["code"].get<int>();
    is_day              = current["is_day"].get<int>();

    if (is_day != 0 && is_day != 1)
    {
        *error_message = "Meletrix returned an invalid is_day value";
        return false;
    }

    if (!convert_temperature(current_temperature,  &weather->current_temperature)
      || !convert_temperature(maximum_temperature, &weather->maximum_temperature)
      || !convert_temperature(minimum_temperature, &weather->minimum_temperature))
    {
        *error_message = "Meletrix returned an invalid temperature";
        return false;
    }

    weather->icon = get_meletrix_icon(weather_code, is_day == 1);
    return true;
}

