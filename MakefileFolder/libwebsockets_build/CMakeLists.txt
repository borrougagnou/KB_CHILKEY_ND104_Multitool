# HOW TO USE:

### Normal build
## cmake -S MakefileFolder/libwebsockets_build -B build/lws_deps/build
## cmake --build build/lws_deps/build

### Visual Studio build
## cmake -S MakefileFolder/libwebsockets_build -B build/lws_deps/build -G "Visual Studio 17 2022" -A Win32 -T v141_xp
## cmake --build build/lws_deps/build --config Release 


# IMPORTANT TO REMEMBER !!!
# This file is in MakefileFolder/libwebsockets_build/
# ROOT_DIR is two levels up from this file !

cmake_minimum_required(VERSION 3.10)
project(Libwebsockets)

# built-in CMake module that provides `ExternalProject_Add()` command
# Allows you to download, configure, build, and install an external project as part of your build process.
include(ExternalProject)

get_filename_component(ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../.." ABSOLUTE)
set(BUILD_BASE "${ROOT_DIR}/build/lws_deps")
set(SRC_DIR "${BUILD_BASE}/src")
set(BUILD_DIR "${BUILD_BASE}/obj")


### OS and Arch Detection
if(WIN32)

    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        set(OS_FOLDER "Windows-x64")
    else()
        set(OS_FOLDER "Windows-x32")
    endif()

elseif(APPLE)

    set(OS_FOLDER "Mac")

elseif(UNIX)

    set(OS_FOLDER "Linux")

endif()

set(INSTALL_DIR "${ROOT_DIR}/src/external/libwebsockets/${OS_FOLDER}")

### Windows XP SP3 Support Flag
set(EXTRA_C_FLAGS "")
if(WIN32 AND MINGW)
    set(EXTRA_C_FLAGS "-D_WIN32_WINNT=0x0501")
endif()


# CMake Flags
set(COMMON_CMAKE_ARGS
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_C_FLAGS=${EXTRA_C_FLAGS}
)


## BUILD PART -----------------

# 1. Build zlib
ExternalProject_Add(zlib
    GIT_REPOSITORY https://github.com/madler/zlib.git
    GIT_TAG v1.3.1
    GIT_SHALLOW TRUE
    SOURCE_DIR ${SRC_DIR}/zlib
    BINARY_DIR ${BUILD_DIR}/zlib
    CMAKE_ARGS
        ${COMMON_CMAKE_ARGS}
        -DBUILD_SHARED_LIBS=OFF
)

# 2. Build mbedTLS
ExternalProject_Add(mbedtls
    GIT_REPOSITORY https://github.com/Mbed-TLS/mbedtls.git
    GIT_TAG v2.28.8
    GIT_SHALLOW TRUE
    SOURCE_DIR ${SRC_DIR}/mbedtls
    BINARY_DIR ${BUILD_DIR}/mbedtls
    CMAKE_ARGS
        ${COMMON_CMAKE_ARGS}
        -DBUILD_SHARED_LIBS=OFF
        -DENABLE_TESTING=OFF
        -DENABLE_PROGRAMS=OFF
    DEPENDS zlib
)

# 3. Build nghttp2
ExternalProject_Add(nghttp2
    GIT_REPOSITORY https://github.com/nghttp2/nghttp2.git
    GIT_TAG v1.62.1
    GIT_SHALLOW TRUE
    SOURCE_DIR ${SRC_DIR}/nghttp2
    BINARY_DIR ${BUILD_DIR}/nghttp2
    CMAKE_ARGS
        ${COMMON_CMAKE_ARGS}
        -DBUILD_SHARED_LIBS=OFF
        -DENABLE_LIB_ONLY=ON
        -DENABLE_STATIC_LIB=ON
    DEPENDS mbedtls
)

# 4. Build libwebsockets
ExternalProject_Add(libwebsockets
    GIT_REPOSITORY https://github.com/warmcat/libwebsockets.git
    GIT_TAG v4.3.3
    GIT_SHALLOW TRUE
    SOURCE_DIR ${SRC_DIR}/lws
    BINARY_DIR ${BUILD_DIR}/lws
    CMAKE_ARGS
        ${COMMON_CMAKE_ARGS}
        -DBUILD_SHARED_LIBS=OFF
        -DLWS_WITH_SSL=ON
        -DLWS_WITH_MBEDTLS=ON
        -DLWS_WITH_ZLIB=ON
        -DLWS_WITH_HTTP2=ON
        -DLWS_WITH_STATIC=ON
        -DLWS_WITH_SHARED=OFF
        -DCMAKE_PREFIX_PATH=${INSTALL_DIR}
    DEPENDS nghttp2
)
