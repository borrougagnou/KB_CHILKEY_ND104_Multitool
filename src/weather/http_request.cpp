#include "include/http_request.hh"

#include <libwebsockets.h>
#include <zlib.h>

#include <chrono>
#include <cctype>
#include <cstddef>
#include <string>
#include <cstring>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <limits>
#include <new>

// was banned because of this user agent... :
//static const char http_user_agent[] = "libwebsockets/4.1.6";
static const char   http_user_agent[] = "Mozilla/5.0 (X11; Linux x86_64; rv:145.0) Gecko/20100101 Firefox/145.0";

static const char         http_accept_encoding[]  = "gzip";
static const std::size_t  gzip_output_buffer_size = 16384u;

static const std::size_t  http_maximum_response_size = 1024u * 1024u; //unsigned int
static const std::size_t  http_read_buffer_size      = 16384u;
static const int          network_timeout_seconds    = 10;
static const int          request_timeout_seconds    = 20;



//
// Gzip Class
//

// HTTP response data (Decode gzip and deflate content with zlib)
class gzip_decoder
{
public:
    gzip_decoder();
    ~gzip_decoder();

    bool reset(int window_bits, std::string *error_message);
    bool decode(const void *data, std::size_t size, std::string *output, std::string *error_message);
    bool finished() const;

private:
    z_stream stream;
    bool     initialized;
    bool     stream_finished;
};


gzip_decoder::gzip_decoder()
{
    this->initialized     = false;
    this->stream_finished = false;

    std::memset(&this->stream, 0, sizeof(this->stream));
}


gzip_decoder::~gzip_decoder()
{
    if (this->initialized)
        inflateEnd(&this->stream);
}


bool gzip_decoder::reset(int window_bits, std::string *error_message)
{
    int zlib_result;

    if (!error_message)
        return false;

    if (this->initialized)
    {
        inflateEnd(&this->stream);
        this->initialized = false;
    }

    std::memset(&this->stream, 0, sizeof(this->stream));
    this->stream_finished = false;

    // initialize the decompression system of zlib
    // (MAX_WBITS + 16 is the size of the history buffer)
    zlib_result = inflateInit2(&this->stream, window_bits);

    if (zlib_result != Z_OK)
    {
        *error_message = "Unable to initialize gzip decompression";
        return false;
    }

    this->initialized = true;
    return true;
}


bool gzip_decoder::decode(const void *data, std::size_t size, std::string *output, std::string *error_message)
{
    unsigned char output_buffer[gzip_output_buffer_size];
    std::size_t   produced_size;
    int           zlib_result;

    if (!output || !error_message)
        return false;

    if (!this->initialized)
    {
        *error_message = "The gzip decoder is not initialized";
        return false;
    }

    if (this->stream_finished)
    {
        *error_message = "Received data after the gzip stream ended";
        return false;
    }

    if (!data && size != 0u)
    {
        *error_message = "Received invalid gzip data";
        return false;
    }

    if (size > static_cast<std::size_t>(std::numeric_limits<uInt>::max()))
    {
        *error_message = "The gzip input block is too large";
        return false;
    }

    this->stream.next_in  = reinterpret_cast<Bytef*>(const_cast<void*>(data));
    this->stream.avail_in = static_cast<uInt>(size);

    do
    {
        this->stream.next_out  = output_buffer;
        this->stream.avail_out = static_cast<uInt>(sizeof(output_buffer));
        zlib_result            = inflate(&this->stream, Z_NO_FLUSH);

        produced_size = sizeof(output_buffer) - this->stream.avail_out;
        if (produced_size != 0u)
        {
            // Limit the ""decompressed body"".
            // A small gzip stream may expand considerably.
            if (produced_size > http_maximum_response_size
              || output->size() > http_maximum_response_size - produced_size)
            {
                *error_message = "HTTP response exceeded the maximum allowed size";
                return false;
            }

            output->append(reinterpret_cast<const char*>(output_buffer), produced_size);
        }

        if (zlib_result == Z_STREAM_END)
        {
            this->stream_finished = true;
            if (this->stream.avail_in != 0u)
            {
                *error_message = "Unexpected data after the gzip stream";
                return false;
            }

            return true;
        }

        if (zlib_result == Z_BUF_ERROR && this->stream.avail_in == 0u)
            return true;

        if (zlib_result != Z_OK)
        {
            *error_message = "Unable to decompress the gzip response";
            if (this->stream.msg)
            {
                *error_message += ": ";
                *error_message += this->stream.msg;
            }

            return false;
        }

    } while (this->stream.avail_in != 0u || this->stream.avail_out == 0u);

    return true;
}


bool gzip_decoder::finished() const
{
    return this->stream_finished;
}


//
// HTTP Request Class
//

class http_client
{
public:
    http_client();
    ~http_client();

    bool initialize(const std::string *ca_certificate_path, std::string *error_message);
    bool get(const char *url, http_response *response, std::string *error_message);

    static int callback(struct lws *wsi, enum lws_callback_reasons reason, void *user, void *in, std::size_t len);

private:
    void fail(const std::string &message);
    void complete(struct lws *wsi);

    struct lws_context *context;
    std::uintptr_t     request_identifier;
    http_response      *response;

    bool               gzip_response;
    gzip_decoder       gzip;

    bool               redirect_response;

    bool               have_ca_certificate;
    std::string        ca_certificate_path;
    bool               ca_warning_shown;

    std::string        *error_message;

    bool               done;
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


http_client::http_client()
{
    this->context             = nullptr;
    this->request_identifier  = 0u;
    this->response            = nullptr;
    this->gzip_response       = false;
    this->redirect_response   = false;
    this->have_ca_certificate = false;
    this->ca_warning_shown    = false;
    this->error_message       = nullptr;
    this->done                = false;
}



http_client::~http_client()
{
    if (this->context)
    {
        lws_context_destroy(this->context);
        this->context = nullptr;
    }
}

// Create the libwebsockets context. (you need do to it only once and the same context will be reused by every request)
bool http_client::initialize(const std::string *certificate_path, std::string *initialization_error)
{
    struct lws_context_creation_info context_info;
    std::ifstream                    ca_file;

    if (!certificate_path || !initialization_error)
        return false;

    initialization_error->clear();

    if (this->context)
        return true;

    this->ca_certificate_path = *certificate_path;
    this->have_ca_certificate = false;
    this->ca_warning_shown    = false;
    if (!this->ca_certificate_path.empty())
    {
        ca_file.open(this->ca_certificate_path.c_str(), std::ios::in | std::ios::binary);

        if (ca_file.good() && ca_file.peek() != std::ifstream::traits_type::eof())
            this->have_ca_certificate = true;

        ca_file.close();
    }

    std::memset(&context_info, 0, sizeof(context_info));

    context_info.port                 = CONTEXT_PORT_NO_LISTEN;
    context_info.protocols            = http_protocols;
    context_info.user                 = this;
    context_info.options              = LWS_SERVER_OPTION_DO_SSL_GLOBAL_INIT
                                      | LWS_SERVER_OPTION_H2_JUST_FIX_WINDOW_UPDATE_OVERFLOW;
    context_info.timeout_secs         = network_timeout_seconds; //general LWS network-operation timeout
    context_info.connect_timeout_secs = network_timeout_seconds; //how long the client connection establishment can take
    context_info.fd_limit_per_thread  = 6;

    if (this->have_ca_certificate)
        context_info.client_ssl_ca_filepath = this->ca_certificate_path.c_str();

    this->context = lws_create_context(&context_info);
    if (!this->context)
    {
        *initialization_error = "Unable to create the libwebsockets context";
        return false;
    }

    return true;
}



void http_client::fail(const std::string &message)
{
    if (this->error_message && this->error_message->empty())
        *this->error_message = message;

    this->done = true;
}


void http_client::complete(struct lws *wsi)
{
    struct lws_context *context;

    // no need gzip validation when the body is empty (redirect)
    if (this->redirect_response)
        return;

    if (this->gzip_response && !this->gzip.finished())
        this->fail("The gzip response ended before the gzip stream completed");
    else
        this->done = true;

    if (!wsi)
        return;

    context = lws_get_context(wsi);

    if (context)
        lws_cancel_service(context);
}


// Receive HTTP events and response data from libwebsockets.
int http_client::callback(struct lws *wsi, enum lws_callback_reasons reason, void *user, void *in, std::size_t len)
{
    http_client        *client;
    struct lws_context *context;
    std::uintptr_t     callback_request_identifier;
    unsigned char      **header_position;
    unsigned char      *header_end;
    char               read_buffer[LWS_PRE + http_read_buffer_size];
    char               *read_position;
    int                read_size;
    char               content_encoding[32];
    int                content_encoding_length;
    int                copy_result_content;
    int                zlib_window_bits;
    std::size_t        i;

    client  = static_cast<http_client*>(user);
    context = nullptr;

    // Some callbacks do not provide the userdata directly.
    // Recover the client through the LWS context in that case.
    if (!client && wsi)
    {
        context = lws_get_context(wsi);
        if (context)
            client = static_cast<http_client*>(lws_context_user(context));
    }

    if (!client)
        return 0;

    if (wsi)
    {
        callback_request_identifier = reinterpret_cast<std::uintptr_t>(lws_get_opaque_user_data(wsi));
        if (callback_request_identifier != client->request_identifier)
            return lws_callback_http_dummy(wsi, reason, user, in, len);
    }

    switch (reason)
    {
        case LWS_CALLBACK_CLIENT_CONNECTION_ERROR:
        {
            if (in && len != 0u)
                client->fail(std::string(static_cast<const char*>(in), len));
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

        case LWS_CALLBACK_CLIENT_HTTP_REDIRECT:
        {
            client->response->status_code = 0u;
            client->response->body.clear();
            client->gzip_response = false;
            client->redirect_response   = true;

            return 0;
        }



        case LWS_CALLBACK_ESTABLISHED_CLIENT_HTTP:
        {
            if (!wsi)
            {
                client->fail("The HTTP connection has no instance for libwebsockets");
                return -1;
            }

            // If a redirect occurred, reading ESTABLISHED again means
            // libwebsockets has reached the next HTTP response.
            client->redirect_response = false;

            // Read the status while the response headers are still available.
            client->response->status_code = lws_http_client_http_response(wsi);

            content_encoding_length = lws_hdr_total_length(wsi, WSI_TOKEN_HTTP_CONTENT_ENCODING);
            if (content_encoding_length <= 0)
                return 0;

            if (content_encoding_length >= static_cast<int>(sizeof(content_encoding)))
            {
                client->fail("The HTTP Content-Encoding header is too long");
                return -1;
            }

            content_encoding[0] = '\0';
            copy_result_content = lws_hdr_copy(wsi,
                                              content_encoding,
                                              sizeof(content_encoding),
                                              WSI_TOKEN_HTTP_CONTENT_ENCODING);
            if (copy_result_content < 0)
            {
                client->fail("Unable to read the HTTP Content-Encoding header");
                return -1;
            }

            for (i = 0u; i < static_cast<std::size_t>(copy_result_content); ++i)
            {
                content_encoding[i] = static_cast<char>(std::tolower(static_cast<unsigned char>(content_encoding[i])));
            }

            if (std::strcmp(content_encoding, "identity") == 0)
                return 0;

            zlib_window_bits = 0;
            if (std::strcmp(content_encoding, "gzip") == 0)
                zlib_window_bits = 16 + MAX_WBITS;
            else if (std::strcmp(content_encoding, "deflate") == 0)
                zlib_window_bits = MAX_WBITS;
            else
            {
                client->fail(std::string("Unsupported HTTP Content-Encoding: ") + content_encoding);
                return -1;
            }

            client->gzip_response = true;
            if (!client->gzip.reset(zlib_window_bits, client->error_message))
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
                                            sizeof(http_user_agent) - 1u,
                                            header_position,
                                            header_end))
            {
                client->fail("Unable to add the User-Agent header");
                return -1;
            }

            if (lws_add_http_header_by_token(wsi,
                                             WSI_TOKEN_HTTP_ACCEPT_ENCODING,
                                             reinterpret_cast<const unsigned char*>(http_accept_encoding),
                                             sizeof(http_accept_encoding) - 1u,
                                             header_position,
                                             header_end))
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
            if (len == 0u)
                return 0;

            if (!in)
            {
                client->fail("The HTTP response contains invalid data");
                return -1;
            }

            if (client->redirect_response)
                return 0;

            if (!client->gzip_response)
            {
                if (len > http_maximum_response_size
                  || client->response->body.size() > http_maximum_response_size - len)
                {
                    client->fail("HTTP response exceeded the maximum allowed size");
                    return -1;
                }
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
            // Report an error if nothing completed the request.
            if (!client->done && !client->redirect_response)
            {
                client->fail("The HTTP connection closed before the request completed");
                if (wsi)
                {
                    context = lws_get_context(wsi);
                    if (context)
                        lws_cancel_service(context);
                }
            }

            return 0;
        }


        default:
            break;
    }

    if (!wsi)
        return 0;

    return lws_callback_http_dummy(wsi, reason, user, in, len);
}


// Execute a single HTTP request (using the existing context). The "Redirect handling" is performed by the get().
bool http_client::get(const char *url, http_response *response, std::string *error_message)
{
    struct lws_client_connect_info        connect_info;
    struct lws                            *connection_result;
    std::chrono::steady_clock::time_point deadline;

    const char                            *protocol;
    bool                                  use_ssl;
    int                                   ssl_connection;

    const char                            *address;
    const char                            *url_path;
    std::string                           url_buffer;
    std::string                           path;
    std::string                           host;
    int                                   port;

    int                                   service_result;

    if (!this->context || !url || !response || !error_message)
        return false;

    ++this->request_identifier;

    if (this->request_identifier == 0u)
        ++this->request_identifier;

    this->response            = response;
    this->error_message       = error_message;

    this->redirect_response   = false;
    this->gzip_response       = false;
    this->done                = false;

    this->response->status_code = 0u;
    this->response->body.clear();
    this->error_message->clear();

    url_buffer = url;
    protocol   = nullptr;
    address    = nullptr;
    url_path   = nullptr;
    port       = 0;

    if (url_buffer.empty()
      || lws_parse_uri(&url_buffer[0], &protocol, &address, &port, &url_path) != 0)
    {
        this->fail("Unable to parse the HTTP URL");
        return false;
    }

    if (!address || address[0] == '\0')
    {
        this->fail("The HTTP URL does not contain a valid host");
        return false;
    }

    use_ssl = false;
    if (protocol && std::strcmp(protocol, "https") == 0)
        use_ssl = true;
    else if (!protocol || std::strcmp(protocol, "http") != 0)
    {
        this->fail("Unsupported HTTP protocol");
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

    if ((use_ssl && port != 443) || (!use_ssl && port != 80))
    {
        host += ":";
        host += std::to_string(port);
    }



    ssl_connection = 0;
    if (use_ssl)
    {
        ssl_connection = LCCSCF_USE_SSL;
        if (!this->have_ca_certificate)
        {
            ssl_connection |= LCCSCF_ALLOW_SELFSIGNED
                            | LCCSCF_ALLOW_EXPIRED
                            | LCCSCF_ALLOW_INSECURE;

            if (!this->ca_warning_shown)
            {
                std::cerr
                    << "WARNING: No readable CA certificate bundle is available."
                    << std::endl
                    << "WARNING: HTTPS certificate verification will be bypassed."
                    << std::endl
                    << "WARNING: To enable HTTPS certificate verification:"
                    << std::endl
                    << "    1. Download the curl CA Extract page:"
                    << std::endl
                    << "        https://curl.se/ca/cacert.pem"
                    << std::endl
                    << "    2. Place it here:"
                    << std::endl
                    << "        "
                    << ca_certificate_path
                    << std::endl;

                this->ca_warning_shown = true;
            }
        }
    }

    std::memset(&connect_info, 0, sizeof(connect_info));

    connect_info.context  = this->context;
    connect_info.address  = address;
    connect_info.port     = port;
    connect_info.path     = path.c_str();
    connect_info.host     = host.c_str();
    connect_info.origin   = address;
    connect_info.method   = "GET";
    connect_info.protocol = http_protocols[0].name;
    connect_info.userdata = this;
    connect_info.opaque_user_data = reinterpret_cast<void*>(this->request_identifier);

    #if defined(LWS_WITH_HTTP2)

    if (use_ssl)
    {
        connect_info.alpn = "h2,http/1.1";
        ssl_connection |= LCCSCF_H2_QUIRK_OVERFLOWS_TXCR
                        | LCCSCF_H2_QUIRK_NGHTTP2_END_STREAM;
    }
    else
        connect_info.alpn = "http/1.1";

    #else

    connect_info.alpn = "http/1.1";

    #endif

    connect_info.ssl_connection = ssl_connection;

    deadline = std::chrono::steady_clock::now() + std::chrono::seconds(request_timeout_seconds);

    connection_result = lws_client_connect_via_info(&connect_info);
    if (!connection_result && !this->done)
        this->fail("Unable to create the HTTP connection");

    while (!this->done)
    {
        service_result = lws_service(this->context, 100);
        if (service_result < 0)
        {
            this->fail("The libwebsockets service loop failed");
            break;
        }

        if (std::chrono::steady_clock::now() >= deadline)
        {
            this->fail("The HTTP request timed out");
            break;
        }
    }

    return this->error_message->empty();
}


// Create one HTTP client and one reusable LWS context.
http_client *create_http_client(const std::string *ca_certificate_path, std::string *error_message)
{
    http_client *http;
    if (!ca_certificate_path || !error_message)
    {
        if (error_message)
            *error_message = "Invalid HTTP client parameters";

        return nullptr;
    }

    error_message->clear();

    http = new (std::nothrow) http_client;
    if (!http)
    {
        *error_message = "Unable to allocate the HTTP client";
        return nullptr;
    }

    if (!http->initialize(ca_certificate_path, error_message))
    {
        delete http;
        return nullptr;
    }

    return http;
}


// Public HTTP interface (here: used by the geolocation and weather providers)
bool get_http_response(http_client *http, const std::string *url, http_response *response, std::string *error_message)
{
    if (!http || !url || !response || !error_message)
    {
        if (error_message)
            *error_message = "Invalid HTTP request parameters";

        return false;
    }

    if (!http->get(url->c_str(), response, error_message))
        return false;

    if (response->status_code == 0u)
    {
        *error_message = "The HTTP server didn't return a valid status code";
        return false;
    }

    if (response->body.empty())
    {
        *error_message = "The HTTP server returned an empty response";
        return false;
    }

    return true;
}


// Destroy the HTTP client and its reusable LWS context.
void destroy_http_client(http_client *http)
{
    delete http;
}
