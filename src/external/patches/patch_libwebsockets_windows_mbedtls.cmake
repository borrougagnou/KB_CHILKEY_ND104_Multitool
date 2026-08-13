# libwebsockets 4.1.6 Windows + mbedTLS socket compatibility patch.
#
# libwebsockets 4.1.6 incorrectly uses the CRT read() / write() functions
# and CRT errno with Winsock sockets in its mbedTLS transport code.
#
# On Windows, Winsock sockets must use send() / recv(), and non-blocking
# socket errors must be checked through WSAGetLastError().
#
# This patch backports the newer libwebsockets behavior:
#
#   write()  -> send()
#   read()   -> recv()
#   errno    -> LWS_ERRNO / WSAEWOULDBLOCK
#
# This allows mbedTLS to correctly return:
#
#   MBEDTLS_ERR_SSL_WANT_WRITE
#   MBEDTLS_ERR_SSL_WANT_READ
#
# instead of treating a normal non-blocking Winsock operation as a fatal
# TLS/network error.


if(NOT LWS_WINDOWS_BUILD)

    message(
        STATUS
        "libwebsockets Windows mbedTLS socket patch: not a Windows build, skipping"
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
    LWS_WINDOWS_SOCKETS_FILE
    "${LWS_SOURCE_DIR}/lib/plat/windows/windows-sockets.c"
)


if(NOT EXISTS "${LWS_WINDOWS_SOCKETS_FILE}")

    message(
        FATAL_ERROR
        "libwebsockets Windows sockets file not found: ${LWS_WINDOWS_SOCKETS_FILE}"
    )

endif()


file(
    READ
    "${LWS_WINDOWS_SOCKETS_FILE}"
    LWS_WINDOWS_SOCKETS_CONTENT
)


set(PATCH_CHANGED FALSE)


# --------------------------------------------------------------------------
# send(): use Winsock send() instead of CRT write()
# --------------------------------------------------------------------------

set(
    OLD_SEND
    "ret = write(fd, buf, len);"
)

set(
    NEW_SEND
    "ret = send(fd, (const char *)buf, (unsigned int)len, 0);"
)


string(
    FIND
    "${LWS_WINDOWS_SOCKETS_CONTENT}"
    "${OLD_SEND}"
    SEND_POSITION
)


if(NOT SEND_POSITION EQUAL -1)

    string(
        REPLACE
        "${OLD_SEND}"
        "${NEW_SEND}"
        LWS_WINDOWS_SOCKETS_CONTENT
        "${LWS_WINDOWS_SOCKETS_CONTENT}"
    )

    set(PATCH_CHANGED TRUE)

else()

    string(
        FIND
        "${LWS_WINDOWS_SOCKETS_CONTENT}"
        "${NEW_SEND}"
        SEND_ALREADY_PATCHED
    )

    if(SEND_ALREADY_PATCHED EQUAL -1)

        message(
            FATAL_ERROR
            "Unable to find the libwebsockets mbedTLS send() code to patch"
        )

    endif()

endif()


# --------------------------------------------------------------------------
# recv(): use Winsock recv() instead of CRT read()
# --------------------------------------------------------------------------

set(
    OLD_RECV
    "ret = (int)read(fd, buf, len);"
)

set(
    NEW_RECV
    "ret = (int)recv(fd, (char *)buf, (unsigned int)len, 0);"
)


string(
    FIND
    "${LWS_WINDOWS_SOCKETS_CONTENT}"
    "${OLD_RECV}"
    RECV_POSITION
)


if(NOT RECV_POSITION EQUAL -1)

    string(
        REPLACE
        "${OLD_RECV}"
        "${NEW_RECV}"
        LWS_WINDOWS_SOCKETS_CONTENT
        "${LWS_WINDOWS_SOCKETS_CONTENT}"
    )

    set(PATCH_CHANGED TRUE)

else()

    string(
        FIND
        "${LWS_WINDOWS_SOCKETS_CONTENT}"
        "${NEW_RECV}"
        RECV_ALREADY_PATCHED
    )

    if(RECV_ALREADY_PATCHED EQUAL -1)

        message(
            FATAL_ERROR
            "Unable to find the libwebsockets mbedTLS recv() code to patch"
        )

    endif()

endif()


# --------------------------------------------------------------------------
# Non-blocking Winsock handling
#
# The original v4.1.6 code checks CRT errno for EAGAIN / EWOULDBLOCK.
# On Windows, use the Winsock error through LWS_ERRNO instead.
#
# In libwebsockets 4.1.6:
#
#     #define LWS_ERRNO WSAGetLastError()
#
# --------------------------------------------------------------------------

set(
    OLD_WOULDBLOCK
    "if (errno == EAGAIN || errno == EWOULDBLOCK)"
)

set(
    NEW_WOULDBLOCK
    "if (LWS_ERRNO == WSAEWOULDBLOCK)"
)


string(
    FIND
    "${LWS_WINDOWS_SOCKETS_CONTENT}"
    "${OLD_WOULDBLOCK}"
    WOULDBLOCK_POSITION
)


if(NOT WOULDBLOCK_POSITION EQUAL -1)

    # There are two occurrences in v4.1.6:
    #
    #   one for MBEDTLS_ERR_SSL_WANT_WRITE
    #   one for MBEDTLS_ERR_SSL_WANT_READ
    #
    # string(REPLACE) intentionally replaces both.

    string(
        REPLACE
        "${OLD_WOULDBLOCK}"
        "${NEW_WOULDBLOCK}"
        LWS_WINDOWS_SOCKETS_CONTENT
        "${LWS_WINDOWS_SOCKETS_CONTENT}"
    )

    set(PATCH_CHANGED TRUE)

else()

    string(
        FIND
        "${LWS_WINDOWS_SOCKETS_CONTENT}"
        "${NEW_WOULDBLOCK}"
        WOULDBLOCK_ALREADY_PATCHED
    )

    if(WOULDBLOCK_ALREADY_PATCHED EQUAL -1)

        message(
            FATAL_ERROR
            "Unable to find the libwebsockets mbedTLS non-blocking socket code to patch"
        )

    endif()

endif()


# --------------------------------------------------------------------------
# Write the modified source
# --------------------------------------------------------------------------

if(PATCH_CHANGED)

    file(
        WRITE
        "${LWS_WINDOWS_SOCKETS_FILE}"
        "${LWS_WINDOWS_SOCKETS_CONTENT}"
    )

    message(
        STATUS
        "Applied libwebsockets Windows mbedTLS socket compatibility patch"
    )

else()

    message(
        STATUS
        "libwebsockets Windows mbedTLS socket compatibility patch already applied"
    )

endif()

# --------------------------------------------------------------------------
# Improve the old v4.1.6 mbedTLS handshake error message.
#
# v4.1.6 normally logs the real native mbedTLS error using lwsl_info().
# INFO logging is compiled out of Release builds, so only the generic
# "mbedtls connect -1 5 <errno>" message is normally visible.
#
# Promote this one fatal-handshake message to ERROR and also display the
# native mbedTLS return code and Winsock error.
# --------------------------------------------------------------------------

set(
    OLD_MBEDTLS_HANDSHAKE_ERROR
    "lwsl_info(\"%s: mbedtls_ssl_handshake() returned -0x%x\\n\", __func__, -ret);"
)

set(
    NEW_MBEDTLS_HANDSHAKE_ERROR
    "lwsl_err(\"%s: mbedtls_ssl_handshake() returned -0x%x (%d), errno %d, WSA %d\\n\", __func__, -ret, ret, errno, WSAGetLastError());"
)

string(
    FIND
    "${LWS_WINDOWS_SOCKETS_CONTENT}"
    "${OLD_MBEDTLS_HANDSHAKE_ERROR}"
    MBEDTLS_HANDSHAKE_ERROR_POSITION
)
