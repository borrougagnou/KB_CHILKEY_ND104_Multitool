#
# Patch libwebsockets 4.x mbedTLS ALPN handling.
#

set(client_file
    "${LWS_SOURCE_DIR}/lib/tls/mbedtls/mbedtls-client.c"
)

set(wrapper_file
    "${LWS_SOURCE_DIR}/lib/tls/mbedtls/wrapper/platform/ssl_pm.c"
)


#
# Defensive caller initialization.
#

file(READ
    "${client_file}"
    client_source
)

set(client_old
"	const unsigned char *prot;
	unsigned int len;"
)

set(client_new
"	const unsigned char *prot = NULL;
	unsigned int len = 0;"
)

string(FIND
    "${client_source}"
    "${client_old}"
    client_match
)

if(client_match EQUAL -1)

    #
    # It may already be patched.
    #
    string(FIND
        "${client_source}"
        "${client_new}"
        client_patched
    )

    if(client_patched EQUAL -1)
        message(FATAL_ERROR
            "Unable to patch ${client_file}: "
            "ALPN declarations were not found"
        )
    endif()

else()

    string(REPLACE
        "${client_old}"
        "${client_new}"
        client_source
        "${client_source}"
    )

    file(WRITE
        "${client_file}"
        "${client_source}"
    )

    message(STATUS
        "Patched mbedtls-client.c ALPN initialization"
    )

endif()



#
# Fix SSL_get0_alpn_selected().
#
# Rather than replacing the complete function, insert initialization
# immediately after its opening brace.  This is less sensitive to small
# differences between LWS revisions.
#

file(READ
    "${wrapper_file}"
    wrapper_source
)

set(wrapper_marker
"void SSL_get0_alpn_selected(const SSL *ssl, const unsigned char **data,
                            unsigned int *len)
{"
)

set(wrapper_replacement
"void SSL_get0_alpn_selected(const SSL *ssl, const unsigned char **data,
			    unsigned int *len)
{
	*data = NULL;
	*len = 0;"
)

string(FIND
    "${wrapper_source}"
    "${wrapper_replacement}"
    wrapper_already_patched
)

if(wrapper_already_patched EQUAL -1)

    string(FIND
        "${wrapper_source}"
        "${wrapper_marker}"
        wrapper_match
    )

    if(wrapper_match EQUAL -1)
        message(FATAL_ERROR
            "Unable to patch ${wrapper_file}: "
            "SSL_get0_alpn_selected() was not found"
        )
    endif()

    string(REPLACE
        "${wrapper_marker}"
        "${wrapper_replacement}"
        wrapper_source
        "${wrapper_source}"
    )

    file(WRITE
        "${wrapper_file}"
        "${wrapper_source}"
    )

    message(STATUS
        "Patched ssl_pm.c ALPN output initialization"
    )

endif()


#
# When LWS negotiates HTTP/2, it migrates the request to a newly-created H2 substream. During that migration it copies:
#
# h2n->swsi->flags = wsi->flags;
# h2n->swsi->a.protocol = wsi->a.protocol;
# h2n->swsi->user_space = wsi->user_space;
#
# but doesn't copy "client_no_follow_redirect"...
# So here's a fix:
#

set(http2_file
    "${LWS_SOURCE_DIR}/lib/roles/h2/http2.c"
)

file(READ
    "${http2_file}"
    http2_source
)

set(http2_old
"			h2n->swsi->flags = wsi->flags;"
)

set(http2_new
"			h2n->swsi->flags = wsi->flags;
			h2n->swsi->client_no_follow_redirect =
					wsi->client_no_follow_redirect;"
)

string(FIND
    "${http2_source}"
    "${http2_new}"
    http2_already_patched
)

if(http2_already_patched EQUAL -1)

    string(FIND
        "${http2_source}"
        "${http2_old}"
        http2_match
    )

    if(http2_match EQUAL -1)
        message(FATAL_ERROR
            "Unable to patch ${http2_file}: "
            "H2 client migration was not found"
        )
    endif()

    string(REPLACE
        "${http2_old}"
        "${http2_new}"
        http2_source
        "${http2_source}"
    )

    file(WRITE
        "${http2_file}"
        "${http2_source}"
    )

    message(STATUS
        "Patched libwebsockets H2 no-follow redirect propagation"
    )

endif()


#
# Backport 4.2 fix into 4.1.6
#

set(http2_file
    "${LWS_SOURCE_DIR}/lib/roles/h2/http2.c"
)

file(READ
    "${http2_file}"
    http2_source
)

set(http2_old
"			h2n->swsi->http.rx_content_remain =
					h2n->swsi->http.rx_content_length;
			lwsl_info(\"setting rx_content_length %lld\\n\","
)

set(http2_new
"			h2n->swsi->http.rx_content_remain =
					h2n->swsi->http.rx_content_length;
			h2n->swsi->http.content_length_given = 1;
			lwsl_info(\"setting rx_content_length %lld\\n\","
)

string(FIND
    "${http2_source}"
    "${http2_new}"
    content_length_already_patched
)

if(content_length_already_patched EQUAL -1)

    string(FIND
        "${http2_source}"
        "${http2_old}"
        content_length_match
    )

    if(content_length_match EQUAL -1)
        message(FATAL_ERROR
            "Unable to patch H2 Content-Length handling"
        )
    endif()

    string(REPLACE
        "${http2_old}"
        "${http2_new}"
        http2_source
        "${http2_source}"
    )

    file(WRITE
        "${http2_file}"
        "${http2_source}"
    )

    message(STATUS
        "Patched libwebsockets backport 4.2 fix into 4.1.6"
    )

endif()



