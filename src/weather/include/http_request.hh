#ifndef HTTP_REQUEST_HH
#define HTTP_REQUEST_HH

#include <string>


class http_client;


struct http_response {
    std::string  body;
    unsigned int status_code;
};


http_client *create_http_client(
    const std::string *ca_certificate_path,
    std::string       *error_message
);

bool get_http_response(
    http_client       *http,
    const std::string *url,
    http_response     *response,
    std::string       *error_message
);

void destroy_http_client(http_client *http);

#endif

