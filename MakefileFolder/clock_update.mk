PROGRAMS += clock_update

CLOCK_BUILD = $(BUILD_DIR)/clock_update

HID_CPPFLAGS_CLOCK = \
	-Isrc/external/hidapi

CPPFLAGS_CLOCK = \
	$(HID_CPPFLAGS_CLOCK)
	# ADD HERE OTHER FLAG IF NEEDED

# COMMON OBJECTS
CLOCK_OBJ = \
	$(CLOCK_BUILD)/hid.o \
	$(CLOCK_BUILD)/main_clock.o \
	$(CLOCK_BUILD)/clock_update.o

# Generate the hid.o build rule for this program
#
# runs `define BUILD_HID` macro from hidapi.mk and replaces $(1) with
#     $(CLOCK_BUILD) and $(2) with $(HID_CPPFLAGS_CLOCK)
# `$(eval ...)` takes the generated Makefile code and adds it to the
#     current Makefile, as if you had written it yourself..
$(eval $(call BUILD_HID,$(CLOCK_BUILD),$(HID_CPPFLAGS_CLOCK)))


# Create objects from C++ sources
$(CLOCK_BUILD)/%.o: src/%.cpp
	@mkdir -p $(@D)
	$(CXX) -c $< $(CPPFLAGS_CLOCK) $(CXXFLAGS) -o $@


# Build the final executable with all object
clock_update: $(CLOCK_OBJ)
ifeq ($(PLATFORM),WINDOWS)
	$(CXX) $^ -o $@.exe -lhid
else ifeq ($(PLATFORM),MAC)
	$(CXX) $^ -o $@ -framework IOKit -framework CoreFoundation
else
	$(CXX) $^ -o $@ -lusb-1.0
endif

