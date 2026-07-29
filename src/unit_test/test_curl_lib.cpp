#include <curl/curl.h>

#include <cstddef>
#include <iostream>
#include <string>


static const char default_test_url[] =
    "https://api.open-meteo.com/v1/forecast"
    "?latitude=52.52"
    "&longitude=13.41"
    "&current=temperature_2m,weather_code,is_day"
    "&daily=temperature_2m_max,temperature_2m_min"
    "&temperature_unit=celsius"
    "&timezone=auto"
    "&forecast_days=1";

/*
   Store the bytes received by libcurl in a string.
*/
static std::size_t store_curl_response(char* data, std::size_t item_size, std::size_t item_count, void* user_data)
{
    std::string *response;
    std::size_t received_size;

    response      = static_cast<std::string*>(user_data);
    received_size = item_size * item_count;

    response->append(data, received_size);

    return received_size;
}

int main(int argc, char** argv)
{
    CURL        *curl_handle;
    CURLcode    curl_result;
    const char  *request_url;
    long        status_code;
    std::string response;
    char        error_buffer[CURL_ERROR_SIZE];

    request_url = default_test_url;

    if (argc >= 2)
        request_url = argv[1];

    error_buffer[0] = '\0';

    curl_result = curl_global_init(CURL_GLOBAL_DEFAULT);
    if (curl_result != CURLE_OK)
    {
        std::cerr << "ERROR: Unable to initialize CURL: " << curl_easy_strerror(curl_result) << std::endl;
        return 1;
    }

    curl_handle = curl_easy_init();
    if (!curl_handle)
    {
        std::cerr << "ERROR: Unable to create CURL request" << std::endl;
        curl_global_cleanup();
        return 1;
    }

    curl_easy_setopt(curl_handle, CURLOPT_URL, request_url);
    curl_easy_setopt(curl_handle, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl_handle, CURLOPT_MAXREDIRS, 5L);
    curl_easy_setopt(curl_handle, CURLOPT_CONNECTTIMEOUT, 10L);
    curl_easy_setopt(curl_handle, CURLOPT_TIMEOUT, 20L);
    curl_easy_setopt(curl_handle, CURLOPT_NOSIGNAL, 1L);
    curl_easy_setopt(curl_handle, CURLOPT_ACCEPT_ENCODING, "");
    curl_easy_setopt(curl_handle, CURLOPT_USERAGENT, "weather-curl-test/1.0");
    curl_easy_setopt(curl_handle, CURLOPT_ERRORBUFFER, error_buffer);
    curl_easy_setopt(curl_handle, CURLOPT_WRITEFUNCTION, store_curl_response);
    curl_easy_setopt(curl_handle, CURLOPT_WRITEDATA, &response);

    std::cout << "Requesting: " << request_url << std::endl;
    curl_result = curl_easy_perform(curl_handle);
    if (curl_result != CURLE_OK)
    {
        std::cerr << "ERROR: CURL request failed: ";

        if (error_buffer[0] != '\0')
            std::cerr << error_buffer;
        else
            std::cerr << curl_easy_strerror(curl_result);

        std::cerr << std::endl;

        curl_easy_cleanup(curl_handle);
        curl_global_cleanup();

        return 1;
    }

    status_code = 0;
    curl_result = curl_easy_getinfo(curl_handle, CURLINFO_RESPONSE_CODE, &status_code);
    if (curl_result != CURLE_OK)
    {
        std::cerr << "ERROR: Unable to read the HTTP status: " << curl_easy_strerror(curl_result) << std::endl;

        curl_easy_cleanup(curl_handle);
        curl_global_cleanup();

        return 1;
    }

    curl_easy_cleanup(curl_handle);
    curl_global_cleanup();

    std::cout << "HTTP status: "    << status_code << std::endl;
    std::cout << "Received bytes: " << response.size() << std::endl;
    std::cout << std::endl << "Raw response:" << std::endl << response << std::endl;

    if (status_code < 200 || status_code >= 300)
    {
        std::cerr << "ERROR: The HTTP server returned an error status" << std::endl;
        return 1;
    }

    if (response.empty())
    {
        std::cerr << "ERROR: The HTTP response is empty" << std::endl;
        return 1;
    }

    std::cout << "CURL access and reading test succeeded" << std::endl;
    return 0;
}

