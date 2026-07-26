#ifndef HTTP_REQUEST_HH
#define HTTP_REQUEST_HH

#include <string>


struct http_response {
    std::string body;
    long        status_code;
};

bool initialize_http(std::string* error_message);
bool get_http_response(const std::string *url, http_response *response, std::string *error_message);
void cleanup_http();

#endif

