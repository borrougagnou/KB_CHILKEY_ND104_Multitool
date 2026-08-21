# - Config file for lws

# It defines the following variables
#  LIBWEBSOCKETS_INCLUDE_DIRS - include directories for FooBar
#  LIBWEBSOCKETS_LIBRARIES    - libraries to link against

# Get the path of the current file.
get_filename_component(LWS_CMAKE_DIR "${CMAKE_CURRENT_LIST_FILE}" PATH)

# Set the include directories.
set(LIBWEBSOCKETS_INCLUDE_DIRS "")

# Include the project Targets file, this contains definitions for IMPORTED targets.
include(${LWS_CMAKE_DIR}/LibwebsocketsTargets.cmake)

# IMPORTED targets from LibwebsocketsTargets.cmake
set(LIBWEBSOCKETS_LIBRARIES websockets websockets_shared)

# These are additional libs that lws wants your app to also link to
foreach(item "/home/runner/work/KB_CHILKEY_ND104_Multitool/KB_CHILKEY_ND104_Multitool/src/external/libwebsockets/Linux/lib/libzlibstatic.a;/home/runner/work/KB_CHILKEY_ND104_Multitool/KB_CHILKEY_ND104_Multitool/src/external/libwebsockets/Linux/lib/libzlibstatic.a;m;dl")
	list(APPEND LIBWEBSOCKETS_DEP_LIBS ${item})
endforeach()

