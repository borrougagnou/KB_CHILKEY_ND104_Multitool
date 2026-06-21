cmake_minimum_required(VERSION 3.15)
project(MyHIDProgram C CXX)

set(CMAKE_CXX_STANDARD 11)

##
## For Linux: You need to install libusb-1.0-0
##

# HIDAPI CONFIG
set(HIDAPI_DIR ${CMAKE_SOURCE_DIR}/src/external/hidapi)

include_directories(${HIDAPI_DIR})

# PLATFORM DETECTION
if (WIN32)

	message(STATUS "Windows Detected")
	set(HID_SRC ${HIDAPI_DIR}/windows/hid.c)

	add_executable(myHIDprogram src/main.cpp ${HID_SRC})

	# Windows HID system lib
	target_link_libraries(myHIDprogram hid)

elseif(APPLE)

	message(STATUS "MacOS Detected")
	set(HID_SRC ${HIDAPI_DIR}/mac/hid.c)

	add_executable(myHIDprogram src/main.cpp ${HID_SRC})

	# MacOS frameworks (IOKit backend)
	find_library(IOKIT IOKit)
	find_library(COREFOUNDATION CoreFoundation)

	target_link_libraries(myHIDprogram
		${IOKIT}
		${COREFOUNDATION}
		pthread
	)

else()

	message(STATUS "Linux Detected")
	set(HID_SRC ${HIDAPI_DIR}/libusb/hid.c)

	add_executable(myHIDprogram src/main.cpp ${HID_SRC})

	# libusb backend
	target_include_directories(myHIDprogram PRIVATE /usr/include/libusb-1.0)

	target_link_libraries(myHIDprogram usb-1.0 pthread)

endif()
