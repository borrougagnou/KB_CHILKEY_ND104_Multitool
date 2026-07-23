PROGRAMS += weather_update

WEATHER_BUILD = $(BUILD_DIR)/weather_update

HID_CPPFLAGS_WEATHER = \
	-Isrc/external/hidapi

CPPFLAGS_WEATHER = \
	$(HID_CPPFLAGS_WEATHER)
	#-DDEBUG
	# ADD HERE OTHER FLAG IF NEEDED

# COMMON OBJECTS
WEATHER_OBJ = \
	$(WEATHER_BUILD)/hid.o \
	$(WEATHER_BUILD)/main_weather.o \
	$(WEATHER_BUILD)/weather_update.o

#WEATHER_OBJ = \
#	$(WEATHER_BUILD)/hid.o \
#	$(WEATHER_BUILD)/weather_update.o



# Generate the hid.o build rule for this program
#
# runs `define BUILD_HID` macro from hidapi.mk and replaces $(1) with
#     $(WEATHER_BUILD) and $(2) with $(HID_CPPFLAGS_WEATHER)
# `$(eval ...)` takes the generated Makefile code and adds it to the
#     current Makefile, as if you had written it yourself..
$(eval $(call BUILD_HID,$(WEATHER_BUILD),$(HID_CPPFLAGS_WEATHER)))


# Create objects from C++ sources
$(WEATHER_BUILD)/%.o: src/%.cpp
	@mkdir -p $(@D)
	$(CXX) -c $< $(CPPFLAGS_WEATHER) $(CXXFLAGS) -o $@


# Build the final executable with all object
weather_update: $(WEATHER_OBJ)
ifeq ($(PLATFORM),WINDOWS)
	$(CXX) $^ -o $@.exe -lhid
else ifeq ($(PLATFORM),MAC)
	$(CXX) $^ -o $@ -framework IOKit -framework CoreFoundation
else
	$(CXX) $^ -o $@ -lusb-1.0
endif

