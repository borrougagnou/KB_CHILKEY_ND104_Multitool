#include "include/weather_config_json.hh"

#include "external/json/json.hpp"

#include <cerrno>
#include <cmath>
#include <cstdlib>
#include <fstream>
#include <limits>
#include <string>


static const char weather_configuration_directory[] = "MYPROGRAM";

static const char weather_configuration_filename[]  = "config.json";

static const std::uint32_t seconds_per_minute        = 60u;
static const std::uint32_t seconds_per_hour          = 60u * 60u;
static const std::uint32_t seconds_per_day           = 24u * 60u * 60u;

static bool has_visible_character(const std::string* value)
{
    std::size_t index;

    for (index = 0; index < value->size(); ++index)
    {
        if ((*value)[index] != ' ' &&
            (*value)[index] != '\t' &&
            (*value)[index] != '\r' &&
            (*value)[index] != '\n')
        {
            return true;
        }
    }

    return false;
}

bool load_weather_configuration(
    weather_configuration* configuration,
    std::string* error_message
)
{
    const char* configuration_base;
    const char* home_directory;
    const nlohmann::json* information_json;
    const nlohmann::json* weather_json;
    nlohmann::json configuration_json;
    std::ifstream configuration_file;
    std::string configuration_path;
    std::string periodic_number_text;
    std::string periodic_run;
    std::string provider_name;
    std::string temperature_name;
    std::size_t periodic_index;
    char* periodic_number_end;
    char periodic_unit;
    unsigned long periodic_number;
    std::uint32_t periodic_multiplier;
    double latitude;
    double longitude;

    if (!configuration || !error_message)
        return false;

    configuration_base = NULL;
    home_directory = NULL;

    #if defined(_WIN32)
    configuration_base = std::getenv("APPDATA");
    if (!configuration_base || configuration_base[0] == '\0')
    {
        *error_message = "The APPDATA environment variable is missing";
        return false;
    }

    configuration_path = configuration_base;
    configuration_path += "\\";
    configuration_path += weather_configuration_directory;
    configuration_path += "\\";
    configuration_path += weather_configuration_filename;

    #elif defined(__APPLE__)
    home_directory = std::getenv("HOME");
    if (!home_directory || home_directory[0] == '\0')
    {
        *error_message = "The HOME environment variable is missing";
        return false;
    }

    configuration_path = home_directory;
    configuration_path += "/Library/Application Support/";
    configuration_path += weather_configuration_directory;
    configuration_path += "/";
    configuration_path += weather_configuration_filename;

    #else
    configuration_base = std::getenv("XDG_CONFIG_HOME");
    if (configuration_base && configuration_base[0] != '\0')
    {
        configuration_path = configuration_base;
    }
    else
    {
        home_directory = std::getenv("HOME");
        if (!home_directory || home_directory[0] == '\0')
        {
            *error_message = "Both XDG_CONFIG_HOME and HOME are missing";
            return false;
        }

        configuration_path = home_directory;
        configuration_path += "/.config";
    }

    configuration_path += "/";
    configuration_path += weather_configuration_directory;
    configuration_path += "/";
    configuration_path += weather_configuration_filename;
    #endif

    configuration_file.open(configuration_path.c_str(), std::ios::in);
    if (!configuration_file.is_open())
    {
        *error_message = "Unable to open configuration file: " + configuration_path;
        return false;
    }

    try
    {
        configuration_json = nlohmann::json::parse(configuration_file);
    }
    catch (const nlohmann::json::exception& exception)
    {
        *error_message = "Invalid JSON in " + configuration_path + ": " + exception.what();
        return false;
    }

    if (!configuration_json.is_object())
    {
        *error_message = "The root JSON value must be an object";
        return false;
    }

    if (!configuration_json.contains("Weather") || !configuration_json["Weather"].is_object())
    {
        *error_message = "The Weather section is missing or is not an object";
        return false;
    }

    weather_json = &configuration_json["Weather"];

    if (!weather_json->contains("temperature_unit") || !(*weather_json)["temperature_unit"].is_string())
    {
        *error_message = "Weather.temperature_unit must be \"C\" or \"F\"";
        return false;
    }

    temperature_name = (*weather_json)["temperature_unit"].get<std::string>();
    if (temperature_name == "C")
        configuration->unit = temperature_celsius;
    else if (temperature_name == "F")
        configuration->unit = temperature_fahrenheit;
    else
    {
        *error_message = "Weather.temperature_unit must be \"C\" or \"F\"";
        return false;
    }

    if (!weather_json->contains("weather_api") || !(*weather_json)["weather_api"].is_string())
    {
        *error_message = "Weather.weather_api must contain a supported provider identifier";
        return false;
    }

    provider_name = (*weather_json)["weather_api"].get<std::string>();
    if (!has_visible_character(&provider_name))
    {
        *error_message = "Weather.weather_api cannot be empty";
        return false;
    }

    if (provider_name == "open_meteo")
        configuration->provider = weather_provider_open_meteo;
    else
    {
        *error_message = "Unsupported Weather.weather_api provider: " + provider_name;
        return false;
    }

    if (!weather_json->contains("geolocation") || !(*weather_json)["geolocation"].is_boolean())
    {
        *error_message = "Weather.geolocation must be true or false";
        return false;
    }

    configuration->use_geolocation = (*weather_json)["geolocation"].get<bool>();

    if (!weather_json->contains("periodic_run") || !(*weather_json)["periodic_run"].is_string())
    {
        *error_message = "Weather.periodic_run must use a value such as 30m, 1h, or 1d";
        return false;
    }

    periodic_run = (*weather_json)["periodic_run"].get<std::string>();
    if (periodic_run.size() < 2)
    {
        *error_message = "Weather.periodic_run must use a value such as 30m, 1h, or 1d";
        return false;
    }

    periodic_unit = periodic_run[periodic_run.size() - 1];
    periodic_number_text = periodic_run.substr(0, periodic_run.size() - 1);
    periodic_multiplier = 0;

    for (periodic_index = 0; periodic_index < periodic_number_text.size(); ++periodic_index)
    {
        if (periodic_number_text[periodic_index] < '0' || periodic_number_text[periodic_index] > '9')
        {
            *error_message = "Weather.periodic_run must begin with a positive whole number";
            return false;
        }
    }

    if (periodic_unit == 'm')
        periodic_multiplier = seconds_per_minute;
    else if (periodic_unit == 'h')
        periodic_multiplier = seconds_per_hour;
    else if (periodic_unit == 'd')
        periodic_multiplier = seconds_per_day;
    else
    {
        *error_message = "Weather.periodic_run unit must be m, h, or d";
        return false;
    }

    errno = 0;
    periodic_number_end = NULL;
    periodic_number = std::strtoul(periodic_number_text.c_str(), &periodic_number_end, 10);

    if (errno != 0 ||
        !periodic_number_end ||
        periodic_number_end[0] != '\0' ||
        periodic_number == 0)
    {
        *error_message = "Weather.periodic_run must begin with a positive whole number";
        return false;
    }

    if (periodic_number >
        std::numeric_limits<std::uint32_t>::max() / periodic_multiplier)
    {
        *error_message = "Weather.periodic_run is too large";
        return false;
    }

    configuration->periodic_run_seconds =
        static_cast<std::uint32_t>(periodic_number) * periodic_multiplier;

    configuration->information.city.clear();
    configuration->information.country.clear();
    configuration->information.latitude = 0.0;
    configuration->information.longitude = 0.0;

    // When geolocation is enabled, Information is optional.
    // It is not accessed or validated.
    if (configuration->use_geolocation)
        return true;

    if (!configuration_json.contains("Information") || !configuration_json["Information"].is_object())
    {
        *error_message = "The Information section is required when Weather.geolocation is false";
        return false;
    }

    information_json = &configuration_json["Information"];

    if (!information_json->contains("city") || !(*information_json)["city"].is_string())
    {
        *error_message = "Information.city is required when Weather.geolocation is false";
        return false;
    }

    configuration->information.city = (*information_json)["city"].get<std::string>();

    if (!has_visible_character(&configuration->information.city))
    {
        *error_message = "Information.city cannot be empty when Weather.geolocation is false";
        return false;
    }

    if (!information_json->contains("country") || !(*information_json)["country"].is_string())
    {
        *error_message = "Information.country is required when Weather.geolocation is false";
        return false;
    }

    configuration->information.country = (*information_json)["country"].get<std::string>();

    if (!has_visible_character(&configuration->information.country))
    {
        *error_message = "Information.country cannot be empty when Weather.geolocation is false";
        return false;
    }

    if (!information_json->contains("lat") ||
        !(*information_json)["lat"].is_number())
    {
        *error_message = "Information.lat must be a number when Weather.geolocation is false";
        return false;
    }

    if (!information_json->contains("lon") ||
        !(*information_json)["lon"].is_number())
    {
        *error_message = "Information.lon must be a number when Weather.geolocation is false";
        return false;
    }

    latitude  = (*information_json)["lat"].get<double>();
    longitude = (*information_json)["lon"].get<double>();

    if (!std::isfinite(latitude) || latitude < -90.0 || latitude > 90.0)
    {
        *error_message = "Information.lat must be between -90 and 90";
        return false;
    }

    if (!std::isfinite(longitude) || longitude < -180.0 || longitude > 180.0)
    {
        *error_message = "Information.lon must be between -180 and 180";
        return false;
    }

    configuration->information.latitude = latitude;
    configuration->information.longitude = longitude;

    return true;
}

