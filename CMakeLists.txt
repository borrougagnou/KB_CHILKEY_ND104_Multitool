# HOW TO USE:
# mkdir cmake-build
# cd cmake-build
# cmake ..
# cmake --build .
#
# Windows architecture can be selected with:
# cmake -DARCH=x64 ..
# cmake -DARCH=x32 ..
## Or with Visual Studio (64):
# cmake -S . -B cmake-build-x64 -A x64
# cmake --build cmake-build-x64
# For Visual Studio (32):
# cmake -S . -B cmake-build-x32 -A Win32
# cmake --build cmake-build-x32

cmake_minimum_required(VERSION 3.15)
project(CHILKEY_ND104_Multitool C CXX)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY         "${CMAKE_BINARY_DIR}")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_BINARY_DIR}")

##
## For Linux: You need to install libusb-1.0-0
##


# PLATFORM DETECTION
set(ARCH "x64" CACHE STRING "Target architecture")
if (WIN32)

	message(STATUS "Windows Detected")
	message(STATUS "Architecture: ${ARCH}")

	# HID library
	set(HIDAPI_DIR ${CMAKE_SOURCE_DIR}/src/external/hidapi)
	set(HID_SRC ${HIDAPI_DIR}/windows/hid.c)

	# JSON library
	set(JSON_SRC ${CMAKE_SOURCE_DIR}/src/external/json)

	# LibWebSockets library
	set(LWS_TEST_INSTALL ${CMAKE_SOURCE_DIR}/src/external/libwebsockets/Windows-${ARCH})
	set(LWS_TEST_LIBRARY ${LWS_TEST_INSTALL}/lib/libwebsockets_static.a)

elseif(APPLE)

	message(STATUS "MacOS Detected")

	# HID library
	set(HIDAPI_DIR ${CMAKE_SOURCE_DIR}/src/external/hidapi)
	set(HID_SRC ${HIDAPI_DIR}/mac/hid.c)

	# JSON library
	set(JSON_SRC ${CMAKE_SOURCE_DIR}/src/external/json)

	# LibWebSockets library
	set(LWS_TEST_INSTALL ${CMAKE_SOURCE_DIR}/src/external/libwebsockets/Mac)
	set(LWS_TEST_LIBRARY ${LWS_TEST_INSTALL}/lib/libwebsockets.a)

else()

	message(STATUS "Linux Detected")

	# HID library
	set(HIDAPI_DIR ${CMAKE_SOURCE_DIR}/src/external/hidapi)
	set(HID_SRC ${HIDAPI_DIR}/libusb/hid.c)

	# JSON library
	set(JSON_SRC ${CMAKE_SOURCE_DIR}/src/external/json)

	# LibWebSockets library
	set(LWS_TEST_INSTALL ${CMAKE_SOURCE_DIR}/src/external/libwebsockets/Linux)
	set(LWS_TEST_LIBRARY ${LWS_TEST_INSTALL}/lib/libwebsockets.a)

endif()


# LibWebSockets must already be built
if(NOT EXISTS ${LWS_TEST_LIBRARY})
	message(FATAL_ERROR "libwebsockets library not found: ${LWS_TEST_LIBRARY}")
endif()

# Static MinGW runtime on Windows (make executables independent of MinGW runtime DLLs)
if(WIN32 AND CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
	add_link_options(-static -static-libgcc -static-libstdc++)
endif()


### Executable & source -----------------

# Clock Program
add_executable(clock_update
	src/clock/main_clock.cpp
	src/clock/clock_update.cpp
)


## Weather Program
#add_executable(weather_update
#	src/weather/main_weather.cpp
#	src/weather/weather_update.cpp
#)

## Picture Program
#add_executable(picture_upload
#	src/weather/main_pictureupload.cpp
#	src/weather/picture_upload.cpp
#)

# TEST JSON Lib Test Program
add_executable(json_lib_test src/unit_test/test_json_lib.cpp)

# TEST LibWebSockets Test Program
add_executable(lws_lib_test src/unit_test/test_libwebsockets_lib.cpp)

### Lib by Program ----------------

# Programs who need HIDAPI
set(HID_PROGRAMS
	clock_update
	#weather_update
	#picture_upload
)

# Programs who need JSON Lib
set(JSON_PROGRAMS
	json_lib_test
	#weather_update
)

# Programs who need LibWebSockets
set(LWS_PROGRAMS
	lws_lib_test
	#weather_update
)

### Lib config ----------------

# HIDAPI Config
## Build HIDAPI as static library
add_library(hidapi STATIC ${HID_SRC})
## Allow the use of: "#include <hidapi.h>"
target_include_directories(hidapi PUBLIC ${HIDAPI_DIR})
if(NOT WIN32 AND NOT APPLE)
	target_include_directories(hidapi PRIVATE
		/usr/include/libusb-1.0
	)
endif()
## Link HIDAPI to programs who use it
foreach(PROGRAM ${HID_PROGRAMS})
	target_link_libraries(${PROGRAM} hidapi)
endforeach()

# JSON Config
foreach(PROGRAM ${JSON_PROGRAMS})
	# Allow the use of: "#include <json.hpp>"
	target_include_directories(${PROGRAM} PRIVATE ${JSON_SRC})
endforeach()

# LibWebSockets Config
foreach(PROGRAM ${LWS_PROGRAMS})
	# Allow the use of: "#include <libwebsockets.h>"
	target_include_directories(${PROGRAM} PRIVATE ${LWS_TEST_INSTALL}/include)
	# Equiv to: "-L$(LWS_TEST_INSTALL)/lib"
	target_link_directories(${PROGRAM} PRIVATE ${LWS_TEST_INSTALL}/lib)
endforeach()


### Libraries -----------------

if(WIN32)

	# HIDAPI with Windows HID system lib below
	foreach(PROGRAM ${HID_PROGRAMS})
		target_link_libraries(${PROGRAM} hid)
	endforeach()

	# JSON libraries
	# NOTHING TO LINK

	# LibWebSockets libraries
	foreach(PROGRAM ${LWS_PROGRAMS})
		# Static LWS applications on Windows
		target_compile_definitions(${PROGRAM} PRIVATE LWS_STATICLIB)
		target_link_libraries(${PROGRAM}
			websockets_static
			mbedtls
			mbedx509
			mbedcrypto
			z
			nghttp2
			ws2_32
			userenv
			crypt32
			iphlpapi
		)
	endforeach()

elseif(APPLE)

	# HIDAPI with MacOS frameworks (IOKit backend) below
	find_library(IOKIT IOKit)
	find_library(COREFOUNDATION CoreFoundation)

	foreach(PROGRAM ${HID_PROGRAMS})
		target_link_libraries(${PROGRAM}
			${IOKIT}
			${COREFOUNDATION}
			pthread
		)
	endforeach()

	# JSON libraries
	# NOTHING TO LINK

	# LibWebSockets libraries
	foreach(PROGRAM ${LWS_PROGRAMS})
		target_link_libraries(${PROGRAM}
			websockets
			mbedtls
			mbedx509
			mbedcrypto
			z
			nghttp2
			pthread
		)
	endforeach()

else()

	# HIDAPI with libusb backend below
	foreach(PROGRAM ${HID_PROGRAMS})
		target_link_libraries(${PROGRAM}
			usb-1.0
			pthread
		)
	endforeach()

	# JSON libraries
	# NOTHING TO LINK

	# LibWebSockets libraries
	foreach(PROGRAM ${LWS_PROGRAMS})
		target_link_libraries(${PROGRAM}
			websockets
			mbedtls
			mbedx509
			mbedcrypto
			z
			nghttp2
			pthread
			dl
			m
		)
	endforeach()

endif()
