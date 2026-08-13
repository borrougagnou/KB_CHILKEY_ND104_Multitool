#include <libwebsockets.h>

#include <zlib.h>

#include <chrono>
#include <cctype>
#include <cstddef>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iostream>
#include <limits>
#include <string>


static const char weather_configuration_directory[] = "weather";
static const char weather_ca_certificate_filename[] = "ca-certificates.pem";
static const char http_user_agent[] = "weather-lws-test/1.0";
static const char http_accept_encoding[] = "gzip";
static const std::size_t http_read_buffer_size = 16384;
static const std::size_t gzip_output_buffer_size = 16384;
static const int network_timeout_seconds = 10;
static const int request_timeout_seconds = 20;
static const unsigned int http_max_redirects = 5;
static const std::size_t http_location_buffer_size = 2048;


static const char default_test_url[] = "https://api.open-meteo.com/v1/forecast"
    "?latitude=52.52"
    "&longitude=13.41"
    "&current=temperature_2m,weather_code,is_day"
    "&daily=temperature_2m_max,temperature_2m_min"
    "&temperature_unit=celsius"
    "&timezone=auto"
    "&forecast_days=1";


static bool get_configuration_file_path(const char *filename, std::string *path, std::string *error_message)
{
    [[maybe_unused]] const char *configuration_base;
    const char *home_directory;

    path->clear();
    error_message->clear();

    #if defined(_WIN32)

    configuration_base = std::getenv("APPDATA");
    if (!configuration_base || configuration_base[0] == '\0')
    {
        *error_message = "The APPDATA environment variable is missing";
        return false;
    }

    *path = configuration_base;
    *path += "\\";
    *path += weather_configuration_directory;
    *path += "\\";
    *path += filename;

    #elif defined(__APPLE__)

    home_directory = std::getenv("HOME");
    if (!home_directory || home_directory[0] == '\0')
    {
        *error_message = "The HOME environment variable is missing";
        return false;
    }

    *path = home_directory;
    *path += "/Library/Application Support/";
    *path += weather_configuration_directory;
    *path += "/";
    *path += filename;

    #else

    configuration_base = std::getenv("XDG_CONFIG_HOME");

    if (configuration_base && configuration_base[0] != '\0')
        *path = configuration_base;
    else
    {
        home_directory = std::getenv("HOME");
        if (!home_directory || home_directory[0] == '\0')
        {
            *error_message = "Both XDG_CONFIG_HOME and HOME are missing";
            return false;
        }

        *path = home_directory;
        *path += "/.config";
    }

    *path += "/";
    *path += weather_configuration_directory;
    *path += "/";
    *path += filename;

    #endif

    return true;
}


struct http_response
{
    unsigned int status_code;
    std::string content_encoding;
    std::string location;
    std::string body;
};


class gzip_decoder
{
public:
    gzip_decoder();
    ~gzip_decoder();

    bool reset(std::string *error_message);
    bool decode(const void *data, std::size_t size, std::string *output, std::string *error_message);
    bool finished() const;

private:
    z_stream stream;
    bool     initialized;
    bool     stream_finished;
};


gzip_decoder::gzip_decoder(): initialized(false), stream_finished(false)
{
    std::memset(&stream, 0, sizeof(stream));
}


gzip_decoder::~gzip_decoder()
{
    if (initialized)
        inflateEnd(&stream);
}


bool gzip_decoder::reset(std::string *error_message)
{
    int zlib_result;

    if (initialized)
    {
        inflateEnd(&stream);
        initialized = false;
    }

    std::memset(&stream, 0, sizeof(stream));
    stream_finished = false;

    // MAX_WBITS + 16 means RFC 1952 gzip.
    zlib_result = inflateInit2(&stream, MAX_WBITS + 16);

    if (zlib_result != Z_OK)
    {
        *error_message = "Unable to initialize gzip decompression";
        return false;
    }

    initialized = true;
    return true;
}


bool gzip_decoder::decode(const void *data, std::size_t size, std::string *output, std::string *error_message)
{
    unsigned char output_buffer[gzip_output_buffer_size];
    std::size_t   produced_size;
    int           zlib_result;

    if (!initialized)
    {
        *error_message = "The gzip decoder is not initialized";
        return false;
    }

    if (stream_finished)
    {
        *error_message = "Received data after the gzip stream ended";
        return false;
    }

    if (!data && size != 0)
    {
        *error_message = "Received invalid gzip data";
        return false;
    }

    if (size > static_cast<std::size_t>(std::numeric_limits<uInt>::max()))
    {
        *error_message = "The gzip input block is too large";
        return false;
    }

    stream.next_in  = reinterpret_cast<Bytef*>(const_cast<void*>(data));
    stream.avail_in = static_cast<uInt>(size);

    do
    {
        stream.next_out  = output_buffer;
        stream.avail_out = static_cast<uInt>(sizeof(output_buffer));
        zlib_result      = inflate(&stream, Z_NO_FLUSH);

        produced_size = sizeof(output_buffer) - stream.avail_out;
        if (produced_size != 0)
            output->append(reinterpret_cast<const char*>(output_buffer), produced_size);

        if (zlib_result == Z_STREAM_END)
        {
            stream_finished = true;
            if (stream.avail_in != 0)
            {
                *error_message = "Unexpected data after the gzip stream";
                return false;
            }

            return true;
        }

        if (zlib_result == Z_BUF_ERROR && stream.avail_in == 0)
            return true;

        if (zlib_result != Z_OK)
        {
            *error_message = "Unable to decompress the gzip response";
            if (stream.msg)
            {
                *error_message += ": ";
                *error_message += stream.msg;
            }

            return false;
        }

    } while (stream.avail_in != 0 || stream.avail_out == 0);

    return true;
}


bool gzip_decoder::finished() const
{
    return stream_finished;
}


class http_client
{
public:
    http_client();

    bool get(const char *url, const char *ca_certificate_path, http_response *response, std::string *error_message);
    static int callback(struct lws *wsi, enum lws_callback_reasons reason, void *user, void *in, std::size_t len);

private:
    bool request(const char *url, const char *ca_certificate_path, http_response *response, std::string *error_message);
    bool resolve_redirect_url(const std::string *current_url, const std::string *location, std::string *redirect_url);
    void fail(const std::string &message);
    void complete(struct lws *wsi);

    http_response                         *response;
    std::string                           *error_message;
    bool                                  ca_warning_shown;
    bool                                  done;
    bool                                  gzip_response;
    gzip_decoder                          gzip;
    std::chrono::steady_clock::time_point deadline;
};


static const struct lws_protocols http_protocols[] =
{
    {
        "http",  http_client::callback, 0, 0, 0, nullptr, 0
    },
    {
        nullptr, nullptr,               0, 0, 0, nullptr, 0
    }
};


http_client::http_client(): response(nullptr), error_message(nullptr), ca_warning_shown(false), done(false), gzip_response(false)
{
}


void http_client::fail(const std::string &message)
{
    if (error_message && error_message->empty())
        *error_message = message;

    done = true;
}


void http_client::complete(struct lws *wsi)
{
    struct lws_context *context;

    if (gzip_response && !gzip.finished())
        fail("The gzip response ended before the gzip stream completed");
    else
        done = true;

    if (!wsi)
        return;

    context = lws_get_context(wsi);

    if (context)
        lws_cancel_service(context);
}


int http_client::callback(struct lws *wsi, enum lws_callback_reasons reason, void *user, void *in, size_t len)
{
    http_client        *client;
    struct lws_context *context;
    unsigned char      **header_position;
    unsigned char      *header_end;
    char               read_buffer[LWS_PRE + http_read_buffer_size];
    char               *read_position;
    int                read_size;
    char               content_encoding[32];
    int                content_encoding_length;
    char               location[http_location_buffer_size];
    int                copy_result_location;
    int                copy_result_content;
    std::size_t        index;


    client  = static_cast<http_client*>(user);
    context = nullptr;

    if (!client && wsi)
    {
        context = lws_get_context(wsi);
        if (context)
            client = static_cast<http_client*>(lws_context_user(context));
    }
    if (!client)
        return 0;

    switch (reason)
    {
        case LWS_CALLBACK_CLIENT_CONNECTION_ERROR:
        {
            if (in && len != 0)
            {
                client->error_message->assign(static_cast<const char*>(in), len);
                client->done = true;
            }
            else
                client->fail("The HTTP connection failed without an error description");

            if (wsi)
            {
                context = lws_get_context(wsi);
                if (context)
                    lws_cancel_service(context);
            }

            return 0;
        }


        case LWS_CALLBACK_ESTABLISHED_CLIENT_HTTP:
        {
            if (!wsi)
            {
                client->fail("The HTTP connection has no websocket instance");
                return -1;
            }

            client->response->status_code = lws_http_client_http_response(wsi);

            if (client->response->status_code == 301
             || client->response->status_code == 302
             || client->response->status_code == 303
             || client->response->status_code == 307
             || client->response->status_code == 308)
            {
                content_encoding_length = lws_hdr_total_length(wsi, WSI_TOKEN_HTTP_LOCATION);
                if (content_encoding_length <= 0)
                {
                    client->fail("The HTTP redirect response has no Location header");
                    return -1;
                }

                if (content_encoding_length >= static_cast<int>(sizeof(location)))
                {
                    client->fail("The HTTP redirect Location header is too long");
                    return -1;
                }

                copy_result_location = lws_hdr_copy(wsi, location, sizeof(location), WSI_TOKEN_HTTP_LOCATION);
                if (copy_result_location < 0)
                {
                    client->fail("Unable to read the HTTP redirect Location header");
                    return -1;
                }

                client->response->location = location;
                client->done               = true;

                context = lws_get_context(wsi);
                if (context)
                    lws_cancel_service(context);

                return 0;
            }

            content_encoding_length = lws_hdr_total_length(wsi, WSI_TOKEN_HTTP_CONTENT_ENCODING);
            if (content_encoding_length <= 0)
                return 0;

            if (content_encoding_length >= static_cast<int>(sizeof(content_encoding)))
            {
                client->fail("The HTTP Content-Encoding header is too long");
                return -1;
            }

            copy_result_content = lws_hdr_copy(wsi, content_encoding, sizeof(content_encoding), WSI_TOKEN_HTTP_CONTENT_ENCODING);
            if (copy_result_content < 0)
            {
                client->fail("Unable to read the HTTP Content-Encoding header");
                return -1;
            }

            for (index = 0; index < static_cast<std::size_t>(copy_result_content); ++index)
            {
                content_encoding[index] = static_cast<char>(std::tolower(static_cast<unsigned char>(content_encoding[index])));
            }

            client->response->content_encoding = content_encoding;
            if (client->response->content_encoding == "identity")
                return 0;

            if (client->response->content_encoding != "gzip")
            {
                client->fail("Unsupported HTTP Content-Encoding: " + client->response->content_encoding);
                return -1;
            }

            client->gzip_response = true;
            if (!client->gzip.reset(client->error_message))
            {
                client->done = true;
                return -1;
            }
            return 0;
        }


        case LWS_CALLBACK_CLIENT_APPEND_HANDSHAKE_HEADER:
        {
            if (!wsi || !in)
            {
                client->fail("Unable to create the HTTP request headers");
                return -1;
            }

            header_position = reinterpret_cast<unsigned char**>(in);
            if (!header_position || !*header_position)
            {
                client->fail("Unable to create the HTTP request headers");
                return -1;
            }

            header_end = *header_position + len;
            if (lws_add_http_header_by_name(wsi,
                                            reinterpret_cast<const unsigned char*>("user-agent:"),
                                            reinterpret_cast<const unsigned char*>(http_user_agent),
                                            sizeof(http_user_agent) - 1,
                                            header_position, header_end))
            {
                client->fail("Unable to add the User-Agent header");
                return -1;
            }

            if (lws_add_http_header_by_token(wsi,
                                             WSI_TOKEN_HTTP_ACCEPT_ENCODING,
                                             reinterpret_cast<const unsigned char*>(http_accept_encoding),
                                             sizeof(http_accept_encoding) - 1,
                                             header_position, header_end))
            {
                client->fail("Unable to add the Accept-Encoding header");
                return -1;
            }

            return 0;
        }


        case LWS_CALLBACK_RECEIVE_CLIENT_HTTP:
        {
            if (!wsi)
            {
                client->fail("Unable to read the HTTP response");
                return -1;
            }

            read_position = read_buffer + LWS_PRE;
            read_size     = static_cast<int>(sizeof(read_buffer) - LWS_PRE);
            if (lws_http_client_read(wsi, &read_position, &read_size) < 0)
            {
                client->fail("Unable to read the HTTP response");
                return -1;
            }

            return 0;
        }


        case LWS_CALLBACK_RECEIVE_CLIENT_HTTP_READ:
        {
            if (len == 0)
                return 0;

            if (!in)
            {
                client->fail("The HTTP response contains invalid data");
                return -1;
            }

            if (!client->gzip_response)
            {
                client->response->body.append(static_cast<const char*>(in), len);
                return 0;
            }

            if (!client->gzip.decode(in, len, &client->response->body, client->error_message))
            {
                client->done = true;
                return -1;
            }

            return 0;
        }

        case LWS_CALLBACK_COMPLETED_CLIENT_HTTP:
        {
            client->complete(wsi);
            return 0;
        }

        case LWS_CALLBACK_CLOSED_CLIENT_HTTP:
        {
            return 0;
        }


        default:
            break;
    }

    if (!wsi)
        return 0;

    return lws_callback_http_dummy(wsi, reason, user, in, len);
}


bool http_client::request(const char *url, const char *ca_certificate_path, http_response *response, std::string *error_message)
{
    struct lws_context_creation_info      context_info;
    struct lws_client_connect_info        connect_info;
    struct lws_context                    *context;
    struct lws                            *client_wsi;
    struct lws                            *connection_result;
    const char                            *protocol;
    const char                            *address;
    const char                            *url_path;
    std::string                           url_buffer;
    std::string                           path;
    std::string                           host;
    std::ifstream                         ca_file;
    int                                   port;
    int                                   service_result;
    int                                   ssl_connection;
    bool                                  have_ca_certificate;

    if (!url || !response || !error_message)
        return false;

    this->response      = response;
    this->error_message = error_message;
    done                = false;
    gzip_response       = false;

    response->status_code      = 0;
    response->content_encoding = "identity";
    response->location.clear();
    response->body.clear();
    error_message->clear();

    url_buffer = url;
    protocol   = nullptr;
    address    = nullptr;
    url_path   = nullptr;
    port       = 0;

    if (url_buffer.empty() || lws_parse_uri(&url_buffer[0], &protocol, &address, &port, &url_path) != 0)
    {
        fail("Unable to parse the HTTP URL");
        return false;
    }

    ssl_connection = 0;
    if (protocol && std::strcmp(protocol, "https") == 0)
        ssl_connection = LCCSCF_USE_SSL;
    else if (!protocol || std::strcmp(protocol, "http") != 0)
    {
        fail("Unsupported HTTP protocol");
        return false;
    }

    path = "/";
    if (url_path && url_path[0] != '\0')
    {
        if (url_path[0] == '/')
            path = url_path;
        else
            path += url_path;
    }

    host = address;

    if (((ssl_connection & LCCSCF_USE_SSL) && port != 443) || (!(ssl_connection & LCCSCF_USE_SSL) && port != 80))
    {
        host += ":";
        host += std::to_string(port);
    }


    // Test the CA file.
    // If the directory not exist, `std::ifstream` will just fail
    have_ca_certificate = false;
    if (ca_certificate_path && ca_certificate_path[0] != '\0')
    {
        ca_file.open(ca_certificate_path, std::ios::in | std::ios::binary);

        if (ca_file.good() && ca_file.peek() != std::ifstream::traits_type::eof())
            have_ca_certificate = true;

        ca_file.close();
    }

    if (!have_ca_certificate)
    {
        ssl_connection |= LCCSCF_ALLOW_SELFSIGNED
                        | LCCSCF_ALLOW_EXPIRED
                        | LCCSCF_ALLOW_INSECURE;

        if (!ca_warning_shown)
        {
            std::cerr
                << "WARNING: No readable CA certificate bundle is available."
                << std::endl
                << "WARNING: HTTPS certificate verification will be bypassed if TLS is used."
                << std::endl;

            ca_warning_shown = true;
        }
    }


    std::memset(&context_info, 0, sizeof(context_info));

    context_info.port                = CONTEXT_PORT_NO_LISTEN;
    context_info.protocols           = http_protocols;
    context_info.user                = this;
    context_info.options             = LWS_SERVER_OPTION_DO_SSL_GLOBAL_INIT;
    context_info.timeout_secs        = network_timeout_seconds;
    context_info.fd_limit_per_thread = 3;

    if (have_ca_certificate)
        context_info.client_ssl_ca_filepath = ca_certificate_path;

    context = lws_create_context(&context_info);
    if (!context)
    {
        fail("Unable to create the libwebsockets context");
        return false;
    }

    std::memset(&connect_info, 0, sizeof(connect_info));

    client_wsi            = nullptr;
    connect_info.context  = context;
    connect_info.address  = address;
    connect_info.port     = port;
    connect_info.path     = path.c_str();
    connect_info.host     = host.c_str();
    connect_info.origin   = address;
    connect_info.method   = "GET";
    connect_info.protocol = http_protocols[0].name;
    connect_info.userdata = this;
    connect_info.pwsi     = &client_wsi;

    ssl_connection |=
        LCCSCF_HTTP_NO_FOLLOW_REDIRECT;

    #if defined(LWS_WITH_HTTP2)

    connect_info.alpn = "h2,http/1.1";
    ssl_connection |= LCCSCF_H2_QUIRK_OVERFLOWS_TXCR
                    | LCCSCF_H2_QUIRK_NGHTTP2_END_STREAM;

    #else

    connect_info.alpn = "http/1.1";

    #endif

    connect_info.ssl_connection = ssl_connection;

    std::cout << "Protocol: "  << protocol                    << std::endl;
    std::cout << "Port: "      << port                        << std::endl;
    std::cout << "ALPN: "      << connect_info.alpn           << std::endl;
    std::cout << "SSL flags: " << connect_info.ssl_connection << std::endl;

    connection_result = lws_client_connect_via_info(&connect_info);
    if (!connection_result && !done)
        fail("Unable to create the HTTP connection");

    while (!done)
    {
        service_result = lws_service(context, 100);
        if (service_result < 0)
        {
            fail("The libwebsockets service loop failed");
            break;
        }

        if (std::chrono::steady_clock::now() >= deadline)
        {
            fail("The HTTP request timed out");
            break;
        }
    }


    lws_context_destroy(context);
    return error_message->empty();
}


bool http_client::resolve_redirect_url(const std::string *current_url, const std::string *location, std::string *redirect_url)
{
    std::string current;
    std::string target;
    std::string origin;
    std::string base_path;
    std::string relative_path;
    std::string query_suffix;
    std::string input_path;
    std::string normalized_path;
    std::size_t fragment_position;
    std::size_t scheme_position;
    std::size_t authority_start;
    std::size_t path_position;
    std::size_t query_position;
    std::size_t origin_end;
    std::size_t target_query_position;
    std::size_t slash_position;
    std::size_t segment_end;
    std::size_t last_slash_position;
    std::size_t index;
    bool absolute_target;

    if (!current_url || !location || !redirect_url)
        return false;

    current = *current_url;
    target  = *location;

    fragment_position = current.find('#');
    if (fragment_position != std::string::npos)
        current.erase(fragment_position);

    fragment_position = target.find('#');
    if (fragment_position != std::string::npos)
        target.erase(fragment_position);

    if (target.empty())
    {
        *redirect_url = current;
        return true;
    }

    absolute_target = false;
    scheme_position = target.find(':');

    if (scheme_position != std::string::npos
     && scheme_position != 0
     && std::isalpha(static_cast<unsigned char>(target[0])))
    {
        absolute_target = true;

        for (index = 1; index < scheme_position; ++index)
        {
            if (!std::isalnum(static_cast<unsigned char>(target[index]))
             && target[index] != '+'
             && target[index] != '-'
             && target[index] != '.')
            {
                absolute_target = false;
                break;
            }
        }
    }

    if (absolute_target)
    {
        *redirect_url = target;
        return true;
    }

    scheme_position = current.find("://");
    if (scheme_position == std::string::npos)
    {
        fail("Unable to resolve the HTTP redirect URL");
        return false;
    }

    if (target.size() >= 2 && target[0] == '/' && target[1] == '/')
    {
        *redirect_url  = current.substr(0, scheme_position);
        *redirect_url += ":";
        *redirect_url += target;
        return true;
    }

    authority_start = scheme_position + 3;
    path_position   = current.find('/', authority_start);
    query_position  = current.find('?', authority_start);

    if (path_position == std::string::npos
     || (query_position != std::string::npos && query_position < path_position))
    {
        origin_end = query_position != std::string::npos ? query_position : current.size();
        origin     = current.substr(0, origin_end);
        base_path.clear();
    }
    else
    {
        origin = current.substr(0, path_position);

        if (query_position == std::string::npos)
            base_path = current.substr(path_position);
        else
            base_path = current.substr(path_position, query_position - path_position);
    }

    if (target[0] == '?')
    {
        *redirect_url  = origin;
        *redirect_url += base_path;
        *redirect_url += target;
        return true;
    }

    target_query_position = target.find('?');
    if (target_query_position == std::string::npos)
    {
        relative_path = target;
        query_suffix.clear();
    }
    else
    {
        relative_path = target.substr(0, target_query_position);
        query_suffix  = target.substr(target_query_position);
    }

    if (!relative_path.empty() && relative_path[0] == '/')
        input_path = relative_path;
    else
    {
        slash_position = base_path.rfind('/');

        if (slash_position == std::string::npos)
        {
            input_path  = "/";
            input_path += relative_path;
        }
        else
        {
            input_path  = base_path.substr(0, slash_position + 1);
            input_path += relative_path;
        }
    }

    normalized_path.clear();

    while (!input_path.empty())
    {
        if (input_path.compare(0, 3, "../") == 0)
            input_path.erase(0, 3);
        else if (input_path.compare(0, 2, "./") == 0)
            input_path.erase(0, 2);
        else if (input_path.compare(0, 3, "/./") == 0)
            input_path.replace(0, 3, "/");
        else if (input_path == "/.")
            input_path = "/";
        else if (input_path.compare(0, 4, "/../") == 0)
        {
            input_path.replace(0, 4, "/");
            last_slash_position = normalized_path.rfind('/');

            if (last_slash_position == std::string::npos)
                normalized_path.clear();
            else
                normalized_path.erase(last_slash_position);
        }
        else if (input_path == "/..")
        {
            input_path = "/";
            last_slash_position = normalized_path.rfind('/');

            if (last_slash_position == std::string::npos)
                normalized_path.clear();
            else
                normalized_path.erase(last_slash_position);
        }
        else if (input_path == "." || input_path == "..")
            input_path.clear();
        else
        {
            if (input_path[0] == '/')
                segment_end = input_path.find('/', 1);
            else
                segment_end = input_path.find('/');

            if (segment_end == std::string::npos)
                segment_end = input_path.size();

            normalized_path.append(input_path, 0, segment_end);
            input_path.erase(0, segment_end);
        }
    }

    if (normalized_path.empty())
        normalized_path = "/";

    *redirect_url  = origin;
    *redirect_url += normalized_path;
    *redirect_url += query_suffix;

    return true;
}


bool http_client::get(const char *url, const char *ca_certificate_path, http_response *response, std::string *error_message)
{
    std::string current_url;
    std::string redirect_url;
    std::size_t fragment_position;
    unsigned int redirect_count;
    bool redirect_response;

    if (!url || !response || !error_message)
        return false;

    this->response      = response;
    this->error_message = error_message;
    ca_warning_shown    = false;

    error_message->clear();

    current_url = url;
    fragment_position = current_url.find('#');
    if (fragment_position != std::string::npos)
        current_url.erase(fragment_position);

    deadline = std::chrono::steady_clock::now() + std::chrono::seconds(request_timeout_seconds);
    redirect_count = 0;

    while (true)
    {
        if (std::chrono::steady_clock::now() >= deadline)
        {
            fail("The HTTP request timed out");
            return false;
        }

        if (!request(current_url.c_str(), ca_certificate_path, response, error_message))
            return false;

        redirect_response = response->status_code == 301
                         || response->status_code == 302
                         || response->status_code == 303
                         || response->status_code == 307
                         || response->status_code == 308;

        if (!redirect_response)
            return true;

        if (response->location.empty())
        {
            fail("The HTTP redirect response has no Location header");
            return false;
        }

        if (redirect_count >= http_max_redirects)
        {
            fail("The HTTP request exceeded the maximum number of redirects");
            return false;
        }

        if (!resolve_redirect_url(&current_url, &response->location, &redirect_url))
            return false;

        ++redirect_count;

        std::cout
            << "Redirect "
            << redirect_count
            << ": HTTP "
            << response->status_code
            << " -> "
            << redirect_url
            << std::endl;

        current_url = redirect_url;
    }
}


int main(int argc, char **argv)
{
    const char    *request_url;
    const char    *ca_certificate_path;
    std::string   ca_path;
    std::string   ca_path_error;
    std::string   error_message;
    http_response response;
    http_client   client;

    request_url = argc >= 2 ? argv[1] : default_test_url;
    ca_certificate_path = nullptr;

    if (get_configuration_file_path(weather_ca_certificate_filename, &ca_path, &ca_path_error))
        ca_certificate_path = ca_path.c_str();
    else
    {
        std::cerr
            << "WARNING: Unable to determine the CA certificate path: "
            << ca_path_error
            << std::endl;
    }

    std::cout << "Requesting: " << request_url << std::endl;

    if (!client.get(request_url, ca_certificate_path, &response, &error_message))
    {
        std::cerr << "ERROR: " << error_message << std::endl;
        return 1;
    }

    std::cout << "HTTP status: "      << response.status_code      << std::endl;
    std::cout << "Content-Encoding: " << response.content_encoding << std::endl;
    std::cout << "Decoded bytes: "    << response.body.size()      << std::endl;

    std::cout << std::endl << "Raw response:" << std::endl << response.body << std::endl;

    if (response.status_code < 200 || response.status_code >= 300)
    {
        std::cerr << "ERROR: The HTTP server returned status " << response.status_code << std::endl;
        return 1;
    }

    if (response.body.empty())
    {
        std::cerr << "ERROR: The HTTP response is empty" << std::endl;
        return 1;
    }

    std::cout << "libwebsockets access and reading test succeeded" << std::endl;
    return 0;
}
