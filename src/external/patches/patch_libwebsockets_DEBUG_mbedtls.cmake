# Temporary DEBUG patch for libwebsockets 4.1.6 + mbedTLS.
#
# libwebsockets 4.1.6 logs the real native mbedTLS handshake error
# using lwsl_info(). In Release builds, INFO logging is normally
# compiled out, so only the generic:
#
#     mbedtls connect -1 5 <errno>
#
# error is visible.
#
# This patch promotes that handshake error to lwsl_err() and also prints:
#
#   - native mbedTLS error code
#   - human-readable mbedTLS error description
#   - CRT errno
#   - Winsock WSAGetLastError()
#
# This patch is only intended for debugging and can be removed once
# the Windows XP TLS problem has been identified.


if(NOT LWS_DEBUG_MBEDTLS_PATCH)

    message(
        STATUS
        "libwebsockets DEBUG mbedTLS patch: disabled, skipping"
    )

    return()

endif()


if(NOT LWS_WINDOWS_BUILD)

    message(
        STATUS
        "libwebsockets DEBUG mbedTLS patch: not a Windows build, skipping"
    )

    return()

endif()


if(NOT DEFINED LWS_SOURCE_DIR)

    message(
        FATAL_ERROR
        "LWS_SOURCE_DIR is not defined"
    )

endif()


set(
    LWS_MBEDTLS_SSL_PM_FILE
    "${LWS_SOURCE_DIR}/lib/tls/mbedtls/wrapper/platform/ssl_pm.c"
)


if(NOT EXISTS "${LWS_MBEDTLS_SSL_PM_FILE}")

    message(
        FATAL_ERROR
        "libwebsockets mbedTLS ssl_pm.c not found: ${LWS_MBEDTLS_SSL_PM_FILE}"
    )

endif()


file(
    READ
    "${LWS_MBEDTLS_SSL_PM_FILE}"
    LWS_MBEDTLS_SSL_PM_CONTENT
)


# Original libwebsockets 4.1.6 handshake error.
set(
    OLD_MBEDTLS_HANDSHAKE_ERROR
    [=[
    lwsl_info("%s: mbedtls_ssl_handshake() returned -0x%x\n", __func__, -ret);
]=]
)


# Temporary detailed error output.
set(
    NEW_MBEDTLS_HANDSHAKE_ERROR
    [=[
    {
        char mbedtls_error[256];

        mbedtls_strerror(
            ret,
            mbedtls_error,
            sizeof(mbedtls_error)
        );

        lwsl_err(
            "%s: mbedtls_ssl_handshake() returned -0x%x (%d): %s; errno %d; WSA %d\n",
            __func__,
            -ret,
            ret,
            mbedtls_error,
            errno,
            WSAGetLastError()
        );
    }
]=]
)


# Check whether the DEBUG patch has already been applied.
string(
    FIND
    "${LWS_MBEDTLS_SSL_PM_CONTENT}"
    "char mbedtls_error[256];"
    PATCH_ALREADY_APPLIED
)


if(NOT PATCH_ALREADY_APPLIED EQUAL -1)

    message(
        STATUS
        "libwebsockets DEBUG mbedTLS patch already applied"
    )

    return()

endif()


# Find the original v4.1.6 code.
string(
    FIND
    "${LWS_MBEDTLS_SSL_PM_CONTENT}"
    "${OLD_MBEDTLS_HANDSHAKE_ERROR}"
    PATCH_LOCATION
)


if(PATCH_LOCATION EQUAL -1)

    message(
        FATAL_ERROR
        "Unable to find the libwebsockets 4.1.6 mbedTLS handshake error code to patch"
    )

endif()


# Apply the DEBUG patch.
string(
    REPLACE
    "${OLD_MBEDTLS_HANDSHAKE_ERROR}"
    "${NEW_MBEDTLS_HANDSHAKE_ERROR}"
    LWS_MBEDTLS_SSL_PM_CONTENT
    "${LWS_MBEDTLS_SSL_PM_CONTENT}"
)


file(
    WRITE
    "${LWS_MBEDTLS_SSL_PM_FILE}"
    "${LWS_MBEDTLS_SSL_PM_CONTENT}"
)


message(
    STATUS
    "Applied libwebsockets DEBUG mbedTLS handshake diagnostic patch"
)

