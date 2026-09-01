PROGRAMS += weather_update

WEATHER_BUILD = $(BUILD_DIR)/weather_update

HID_CPPFLAGS_WEATHER = \
	-Isrc/external/hidapi

JSON_CPPFLAGS_WEATHER = \
	-Isrc/external/json

########## LWS CONFIG
ifeq ($(PLATFORM),WINDOWS)
    ARCH ?= x64
    LWS_DIR_NAME := Windows-$(ARCH)
else ifeq ($(PLATFORM),MAC)
    LWS_DIR_NAME := Mac
else
    LWS_DIR_NAME := Linux
endif

LWS_INSTALL_WEATHER  = src/external/libwebsockets/$(LWS_DIR_NAME)
LWS_CPPFLAGS_WEATHER = -I$(LWS_INSTALL_WEATHER)/include
LWS_LDFLAGS_WEATHER  = -L$(LWS_INSTALL_WEATHER)/lib

ifeq ($(PLATFORM),WINDOWS)
    LWS_CPPFLAGS_WEATHER += -DLWS_STATICLIB
    LWS_LDLIBS_WEATHER    = -lwebsockets_static -lmbedtls -lmbedx509 -lmbedcrypto -lz -lnghttp2 -lws2_32 -luserenv -lcrypt32 -liphlpapi
    LWS_LIBRARY_WEATHER   = $(LWS_INSTALL_WEATHER)/lib/libwebsockets_static.a
else ifeq ($(PLATFORM),MAC)
    LWS_LDLIBS_WEATHER  = -lwebsockets -lmbedtls -lmbedx509 -lmbedcrypto -lz -lnghttp2 -lpthread
    LWS_LIBRARY_WEATHER = $(LWS_INSTALL_WEATHER)/lib/libwebsockets.a
else
    LWS_LDLIBS_WEATHER  = -lwebsockets -lmbedtls -lmbedx509 -lmbedcrypto -lz -lnghttp2 -lpthread -ldl -lm
    LWS_LIBRARY_WEATHER = $(LWS_INSTALL_WEATHER)/lib/libwebsockets.a
endif

$(LWS_LIBRARY_WEATHER):
	$(error libwebsockets library not found: $(LWS_LIBRARY_WEATHER))

CPPFLAGS_WEATHER = \
	$(HID_CPPFLAGS_WEATHER) \
	$(JSON_CPPFLAGS_WEATHER) \
	$(LWS_CPPFLAGS_WEATHER) \
	-Isrc/weather/include \
	-Isrc/weather/include/weather_sources
	#-DDEBUG
	# ADD HERE OTHER FLAG IF NEEDED

# COMMON OBJECTS
WEATHER_SOURCE_OBJ = \
	$(WEATHER_BUILD)/weather_sources/open_meteo.o \
	$(WEATHER_BUILD)/weather_sources/meletrix.o


WEATHER_OBJ = \
	$(WEATHER_BUILD)/hid.o \
	$(WEATHER_BUILD)/main_weather.o \
	$(WEATHER_BUILD)/weather_orchestrator.o \
	$(WEATHER_BUILD)/config_file_path_discovery.o \
	$(WEATHER_BUILD)/config_json_parser.o \
	$(WEATHER_BUILD)/http_request.o \
	$(WEATHER_BUILD)/ip_geolocation.o \
	$(WEATHER_SOURCE_OBJ) \
	$(WEATHER_BUILD)/hid_protocol_for_weather.o


# Generate the hid.o build rule for this program
#
# runs `define BUILD_HID` macro from hidapi.mk and replaces $(1) with
#     $(WEATHER_BUILD) and $(2) with $(HID_CPPFLAGS_WEATHER)
# `$(eval ...)` takes the generated Makefile code and adds it to the
#     current Makefile, as if you had written it yourself..
$(eval $(call BUILD_HID,$(WEATHER_BUILD),$(HID_CPPFLAGS_WEATHER)))


# Create objects from C++ sources
$(WEATHER_BUILD)/%.o: src/weather/%.cpp
	@mkdir -p $(@D)
	$(CXX) -c $< $(CPPFLAGS_WEATHER) $(CXXFLAGS) -o $@

$(WEATHER_BUILD)/weather_sources/%.o: src/weather/weather_sources/%.cpp
	@mkdir -p $(@D)
	$(CXX) -c $< $(CPPFLAGS_WEATHER) $(CXXFLAGS) -o $@

# Build the final executable with all object
weather_update: $(WEATHER_OBJ) $(LWS_LIBRARY_WEATHER)
ifeq ($(PLATFORM),WINDOWS)
	$(CXX) $(WINDOWS_STATIC_LDFLAGS) $(LWS_LDFLAGS_WEATHER) $(WEATHER_OBJ) -o $@.exe -lhid  $(LWS_LDLIBS_WEATHER)
else ifeq ($(PLATFORM),MAC)
	$(CXX) $(LWS_LDFLAGS_WEATHER) $(WEATHER_OBJ) -o $@  $(LWS_LDLIBS_WEATHER) -framework IOKit -framework CoreFoundation
else
	$(CXX) $(LWS_LDFLAGS_WEATHER) $(WEATHER_OBJ) -o $@ -lusb-1.0  $(LWS_LDLIBS_WEATHER)
endif

