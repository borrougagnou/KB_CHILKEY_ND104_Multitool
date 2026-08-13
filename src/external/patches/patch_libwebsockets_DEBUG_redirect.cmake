#
# Temporary libwebsockets 4.1.6 redirect diagnostics.
#
# Apply this AFTER the normal libwebsockets patches.
#
# WARNING !!! : THE FLAG "LWS_DEBUG_REDIRECT_PATCH" SHOULD BE ENABLED !!!
# cmake -S MakefileFolder/libwebsockets_build -B build/lws_deps/build -DLWS_DEBUG_REDIRECT_PATCH=ON
# or
# cmake -S MakefileFolder/libwebsockets_build -B build/lws_deps/build -G "Visual Studio 17 2022" -A Win32 -T v141_xp -DLWS_DEBUG_REDIRECT_PATCH=ON
# cmake --build build/lws_deps/build --config Release
#

if(NOT LWS_DEBUG_REDIRECT_PATCH)
    message(STATUS "libwebsockets DEBUG redirect patch: skipped")
    return()
endif()


set(http2_file
    "${LWS_SOURCE_DIR}/lib/roles/h2/http2.c"
)

set(client_http_file
    "${LWS_SOURCE_DIR}/lib/roles/http/client/client-http.c"
)


#
# 1. Log the HTTP/2 client migration.
#
# This requires the existing client_no_follow_redirect propagation
# patch to already be applied.
#

file(READ
    "${http2_file}"
    http2_source
)

set(http2_marker
"			h2n->swsi->client_no_follow_redirect =
					wsi->client_no_follow_redirect;"
)

set(http2_debug
"			h2n->swsi->client_no_follow_redirect =
					wsi->client_no_follow_redirect;

			lwsl_notice(
				\"TEST H2 MIGRATE: src_nofollow=%d dst_nofollow=%d src_flags=0x%x dst_flags=0x%x\\n\",
				wsi->client_no_follow_redirect,
				h2n->swsi->client_no_follow_redirect,
				(unsigned int)wsi->flags,
				(unsigned int)h2n->swsi->flags
			);"
)

string(FIND
    "${http2_source}"
    "TEST H2 MIGRATE:"
    http2_already_patched
)

if(http2_already_patched EQUAL -1)

    string(FIND
        "${http2_source}"
        "${http2_marker}"
        http2_match
    )

    if(http2_match EQUAL -1)
        message(FATAL_ERROR
            "Unable to add redirect diagnostics to ${http2_file}: "
            "client_no_follow_redirect propagation patch was not found"
        )
    endif()

    string(REPLACE
        "${http2_marker}"
        "${http2_debug}"
        http2_source
        "${http2_source}"
    )

    file(WRITE
        "${http2_file}"
        "${http2_source}"
    )

    message(STATUS
        "Added H2 redirect migration diagnostics"
    )

else()

    message(STATUS
        "H2 redirect migration diagnostics already present"
    )

endif()


#
# 2. Log the parsed HTTP response immediately before LWS decides
#    whether it should automatically follow the redirect.
#

file(READ
    "${client_http_file}"
    client_http_source
)

set(response_marker
"	n = atoi(p);
	if (ah)
		ah->http_response = n;"
)

set(response_debug
"	n = atoi(p);
	if (ah)
		ah->http_response = n;

	lwsl_notice(
		\"TEST HTTP RESPONSE: status=%d nofollow=%d mux=%d flags=0x%x location=%s\\n\",
		n,
		wsi->client_no_follow_redirect,
		wsi->client_mux_substream,
		(unsigned int)wsi->flags,
		lws_hdr_simple_ptr(wsi, WSI_TOKEN_HTTP_LOCATION) ?
			lws_hdr_simple_ptr(wsi, WSI_TOKEN_HTTP_LOCATION) :
			\"(none)\"
	);"
)

string(FIND
    "${client_http_source}"
    "TEST HTTP RESPONSE:"
    response_already_patched
)

if(response_already_patched EQUAL -1)

    string(FIND
        "${client_http_source}"
        "${response_marker}"
        response_match
    )

    if(response_match EQUAL -1)
        message(FATAL_ERROR
            "Unable to add HTTP response diagnostics to "
            "${client_http_file}"
        )
    endif()

    string(REPLACE
        "${response_marker}"
        "${response_debug}"
        client_http_source
        "${client_http_source}"
    )

    file(WRITE
        "${client_http_file}"
        "${client_http_source}"
    )

    message(STATUS
        "Added HTTP redirect response diagnostics"
    )

else()

    message(STATUS
        "HTTP redirect response diagnostics already present"
    )

endif()


#
# 3. Log immediately before ESTABLISHED_CLIENT_HTTP is emitted.
#
# Reload the file because the previous section may have modified it.
#

file(READ
    "${client_http_file}"
    client_http_source
)

set(established_marker
"		wsi->rxflow_change_to = LWS_RXFLOW_ALLOW;

		/* call him back to inform him he is up */"
)

set(established_debug
"		wsi->rxflow_change_to = LWS_RXFLOW_ALLOW;

		lwsl_notice(
			\"TEST ESTABLISHED CALLBACK: status=%d nofollow=%d mux=%d\\n\",
			wsi->http.ah ? wsi->http.ah->http_response : 0,
			wsi->client_no_follow_redirect,
			wsi->client_mux_substream
		);

		/* call him back to inform him he is up */"
)

string(FIND
    "${client_http_source}"
    "TEST ESTABLISHED CALLBACK:"
    established_already_patched
)

if(established_already_patched EQUAL -1)

    string(FIND
        "${client_http_source}"
        "${established_marker}"
        established_match
    )

    if(established_match EQUAL -1)
        message(FATAL_ERROR
            "Unable to add established callback diagnostics to "
            "${client_http_file}"
        )
    endif()

    string(REPLACE
        "${established_marker}"
        "${established_debug}"
        client_http_source
        "${client_http_source}"
    )

    file(WRITE
        "${client_http_file}"
        "${client_http_source}"
    )

    message(STATUS
        "Added established-client diagnostics"
    )

else()

    message(STATUS
        "Established-client diagnostics already present"
    )

endif()


message(STATUS
    "Temporary libwebsockets redirect diagnostics applied"
)

