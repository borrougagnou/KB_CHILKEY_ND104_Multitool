#include "include/http_request.hh"

#include <curl/curl.h>

#include <cstddef>
#include <string>


static const std::size_t http_maximum_response_size = 1024u * 1024u; //unsigned int
static const long        http_connection_timeout    = 10L;
static const long        http_request_timeout       = 20L;
static const long        http_maximum_redirects     = 5L;
static const char        http_user_agent[]          = "weather-app/1.0";

static std::size_t append_http_response(char *received_data, std::size_t item_size, std::size_t item_count, void *user_data)
{
    std::size_t   received_size;
    http_response *response;

    received_size = item_size * item_count;
    response      = static_cast<http_response*>(user_data);

    if (received_size > http_maximum_response_size ||
        response->body.size() > http_maximum_response_size - received_size)
    {
        return 0;
    }

    response->body.append(received_data, received_size);

    return received_size;
}

void cleanup_http()
{
    curl_global_cleanup();
}

bool get_http_response(const std::string *url, http_response *response, std::string* error_message)
{
    CURL     *curl_handle;
    CURLcode curl_result;
    CURLcode option_result;

    if (!url || !response)
    {
        if (error_message)
            *error_message = "Invalid HTTP request parameters";

        return false;
    }

    response->body.clear();
    response->status_code = 0;

    curl_handle = curl_easy_init();
    if (!curl_handle)
    {
        if (error_message)
            *error_message = "Unable to create the libcurl request handle";

        return false;
    }

    option_result = curl_easy_setopt(curl_handle, CURLOPT_URL, url->c_str());
    if (option_result == CURLE_OK)
        option_result = curl_easy_setopt(curl_handle, CURLOPT_FOLLOWLOCATION, 1L);
    if (option_result == CURLE_OK)
        option_result = curl_easy_setopt(curl_handle, CURLOPT_MAXREDIRS, http_maximum_redirects);
    if (option_result == CURLE_OK)
        option_result = curl_easy_setopt(curl_handle, CURLOPT_CONNECTTIMEOUT, http_connection_timeout);
    if (option_result == CURLE_OK)
        option_result = curl_easy_setopt(curl_handle, CURLOPT_TIMEOUT, http_request_timeout);
    if (option_result == CURLE_OK)
        option_result = curl_easy_setopt(curl_handle, CURLOPT_NOSIGNAL, 1L);
    if (option_result == CURLE_OK)
        option_result = curl_easy_setopt(curl_handle, CURLOPT_ACCEPT_ENCODING, "");
    if (option_result == CURLE_OK)
        option_result = curl_easy_setopt(curl_handle, CURLOPT_USERAGENT, http_user_agent);
    if (option_result == CURLE_OK)
        option_result = curl_easy_setopt(curl_handle, CURLOPT_WRITEFUNCTION, append_http_response);
    if (option_result == CURLE_OK)
        option_result = curl_easy_setopt(curl_handle, CURLOPT_WRITEDATA, response);

    if (option_result != CURLE_OK)
    {
        if (error_message)
            *error_message = curl_easy_strerror(option_result);

        curl_easy_cleanup(curl_handle);
        return false;
    }

    curl_result = curl_easy_perform(curl_handle);
    if (curl_result != CURLE_OK)
    {
        if (error_message)
        {
            if (curl_result == CURLE_WRITE_ERROR && response->body.size() >= http_maximum_response_size)
                *error_message = "HTTP response exceeded the maximum allowed size";
            else
                *error_message = curl_easy_strerror(curl_result);
        }

        curl_easy_cleanup(curl_handle);
        return false;
    }

    curl_result = curl_easy_getinfo( curl_handle, CURLINFO_RESPONSE_CODE, &response->status_code);

    if (curl_result != CURLE_OK)
    {
        if (error_message)
            *error_message = curl_easy_strerror(curl_result);

        curl_easy_cleanup(curl_handle);
        return false;
    }

    curl_easy_cleanup(curl_handle);

    if (response->body.empty())
    {
        if (error_message)
            *error_message = "The HTTP server returned an empty response";

        return false;
    }

    return true;
}


bool initialize_http(std::string* error_message)
{
    CURLcode curl_result;

    curl_result = curl_global_init(CURL_GLOBAL_DEFAULT);
    if (curl_result != CURLE_OK)
    {
        if (error_message)
            *error_message = curl_easy_strerror(curl_result);

        return false;
    }

    return true;
}

