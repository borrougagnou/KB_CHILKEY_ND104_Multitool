#include <json.hpp>

#include <cmath>
#include <fstream>
#include <iostream>
#include <string>


int main(int argc, char** argv)
{
    std::string          configuration_path;
    std::ifstream        configuration_file;
    nlohmann::json       configuration_json;
    const nlohmann::json *weather_json;
    const nlohmann::json *information_json;
    std::string          temperature_unit;
    std::string          weather_api;
    std::string          periodic_run;
    bool                 use_geolocation;
    double               latitude;
    double               longitude;

    configuration_path = "config.json";

    if (argc >= 2)
        configuration_path = argv[1];

    configuration_file.open(configuration_path.c_str(), std::ios::in);

    if (!configuration_file.is_open())
    {
        std::cerr << "ERROR: Unable to open JSON file: " << configuration_path << std::endl;
        return 1;
    }

    try
    {
        configuration_file >> configuration_json;
    }
    catch (const nlohmann::json::exception& exception)
    {
        std::cerr << "ERROR: Unable to parse JSON: " << exception.what() << std::endl;
        return 1;
    }

    if (!configuration_json.is_object())
    {
        std::cerr << "ERROR: The root JSON value is not an object" << std::endl;
        return 1;
    }

    if (configuration_json.find("Weather") == configuration_json.end() || !configuration_json["Weather"].is_object())
    {
        std::cerr << "ERROR: The Weather section is missing or invalid" << std::endl;
        return 1;
    }

    weather_json = &configuration_json["Weather"];

    if (weather_json->find("temperature_unit") == weather_json->end() || !(*weather_json)["temperature_unit"].is_string())
    {
        std::cerr << "ERROR: Weather.temperature_unit is missing or invalid" << std::endl;
        return 1;
    }

    temperature_unit = (*weather_json)["temperature_unit"].get<std::string>();

    if (temperature_unit != "C" && temperature_unit != "F")
    {
        std::cerr << "ERROR: Weather.temperature_unit must be C or F" << std::endl;
        return 1;
    }

    if (weather_json->find("weather_api") == weather_json->end() || !(*weather_json)["weather_api"].is_string())
    {
        std::cerr << "ERROR: Weather.weather_api is missing or invalid" << std::endl;
        return 1;
    }

    weather_api = (*weather_json)["weather_api"].get<std::string>();

    if (weather_api.empty())
    {
        std::cerr << "ERROR: Weather.weather_api cannot be empty" << std::endl;
        return 1;
    }

    if (weather_json->find("geolocation") == weather_json->end() || !(*weather_json)["geolocation"].is_boolean())
    {
        std::cerr << "ERROR: Weather.geolocation is missing or invalid" << std::endl;
        return 1;
    }

    use_geolocation = (*weather_json)["geolocation"].get<bool>();

    if (weather_json->find("periodic_run") == weather_json->end() || !(*weather_json)["periodic_run"].is_string())
    {
        std::cerr << "ERROR: Weather.periodic_run is missing or invalid" << std::endl;
        return 1;
    }

    periodic_run = (*weather_json)["periodic_run"].get<std::string>();

    std::cout << "JSON file opened and parsed successfully" << std::endl;
    std::cout << "Temperature unit: " << temperature_unit << std::endl;
    std::cout << "Weather API: " << weather_api << std::endl;
    std::cout << "Geolocation: " << (use_geolocation ? "true" : "false") << std::endl;
    std::cout << "Periodic run: " << periodic_run << std::endl;


    // Information is optional when geolocation is enabled.
    if (use_geolocation)
    {
        std::cout << "Information section is not required" << std::endl;
        return 0;
    }

    if (configuration_json.find("Information") == configuration_json.end() || !configuration_json["Information"].is_object())
    {
        std::cerr << "ERROR: Information is required when " << "geolocation is false" << std::endl;
        return 1;
    }

    information_json = &configuration_json["Information"];

    if (information_json->find("city") == information_json->end() || !(*information_json)["city"].is_string() || (*information_json)["city"].get<std::string>().empty())
    {
        std::cerr << "ERROR: Information.city is missing or empty" << std::endl;
        return 1;
    }

    if (information_json->find("country") == information_json->end() || !(*information_json)["country"].is_string() || (*information_json)["country"].get<std::string>().empty())
    {
        std::cerr << "ERROR: Information.country is missing or empty" << std::endl;
        return 1;
    }

    if (information_json->find("lat") == information_json->end() || !(*information_json)["lat"].is_number())
    {
        std::cerr << "ERROR: Information.lat is missing or invalid" << std::endl;
        return 1;
    }

    if (information_json->find("lon") == information_json->end() || !(*information_json)["lon"].is_number())
    {
        std::cerr << "ERROR: Information.lon is missing or invalid" << std::endl;
        return 1;
    }

    latitude = (*information_json)["lat"].get<double>();
    longitude = (*information_json)["lon"].get<double>();

    if (!std::isfinite(latitude) || latitude < -90.0 || latitude > 90.0)
    {
        std::cerr << "ERROR: Latitude must be between -90 and 90" << std::endl;
        return 1;
    }

    if (!std::isfinite(longitude) || longitude < -180.0 || longitude > 180.0)
    {
        std::cerr << "ERROR: Longitude must be between -180 and 180" << std::endl;
        return 1;
    }

    std::cout << "City: "      << (*information_json)["city"].get<std::string>()    << std::endl;
    std::cout << "Country: "   << (*information_json)["country"].get<std::string>() << std::endl;
    std::cout << "Latitude: "  << latitude  << std::endl;
    std::cout << "Longitude: " << longitude << std::endl;

    return 0;
}

