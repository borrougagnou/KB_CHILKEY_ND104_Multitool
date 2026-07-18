# HOW TO USE:
# mkdir cmake-build
# cd cmake-build
# cmake ..
# cmake --build .

cmake_minimum_required(VERSION 3.15)
project(CHILKEY_ND104_Multitool C CXX)

set(CMAKE_CXX_STANDARD 11)

##
## For Linux: You need to install libusb-1.0-0
##

### HIDAPI Config -----------------
set(HIDAPI_DIR ${CMAKE_SOURCE_DIR}/src/external/hidapi)

include_directories(${HIDAPI_DIR})

# PLATFORM DETECTION
if (WIN32)

	message(STATUS "Windows Detected")
	set(HID_SRC ${HIDAPI_DIR}/windows/hid.c)

elseif(APPLE)

	message(STATUS "MacOS Detected")
	set(HID_SRC ${HIDAPI_DIR}/mac/hid.c)

else()

	message(STATUS "Linux Detected")
	set(HID_SRC ${HIDAPI_DIR}/libusb/hid.c)

endif()

# HIDAPI library
add_library(hidapi STATIC
	${HID_SRC}
)

target_include_directories(hidapi PRIVATE
	${HIDAPI_DIR}
)


if(NOT WIN32 AND NOT APPLE)
	target_include_directories(hidapi PRIVATE
		/usr/include/libusb-1.0
	)
endif()

### Executable -----------------

# Clock Program
add_executable(clock_update
	src/main_clock.cpp
	src/clock_update.cpp
)

target_link_libraries(clock_update
	hidapi
)

## Weather Program
#add_executable(weather_update
#	src/main_weather.cpp
#	src/weather_update.cpp
#)
#
#target_link_libraries(weather_update
#	hidapi
#)

## Picture Program
#add_executable(picture_upload
#	src/main_pictureupload.cpp
#	src/picture_upload.cpp
#)
#
#target_link_libraries(picture_upload
#	hidapi
#)


### Libraries -----------------

if(WIN32)

        # Windows HID system lib
	target_link_libraries(clock_update   hid)
	#target_link_libraries(weather_update hid)
	#target_link_libraries(picture_upload hid)

elseif(APPLE)

	# MacOS frameworks (IOKit backend)
	find_library(IOKIT IOKit)
	find_library(COREFOUNDATION CoreFoundation)

	foreach(PROGRAM
		clock_update
		#weather_update
		#picture_upload
	)
		target_link_libraries(${PROGRAM}
			${IOKIT}
			${COREFOUNDATION}
			pthread
		)
	endforeach()

else()

        # libusb backend
	foreach(PROGRAM
		clock_update
		#weather_update
		#picture_upload
	)
		target_link_libraries(${PROGRAM}
			usb-1.0
			pthread
		)
	endforeach()

endif()
