PROGRAMS += json_lib_test

JSON_TEST_BUILD = $(BUILD_DIR)/json_lib_test


CPPFLAGS_JSON_TEST = \
	-Isrc/external/json
	# ADD HERE OTHER FLAG IF NEEDED

# COMMON OBJECTS
JSON_TEST_OBJ = \
	$(JSON_TEST_BUILD)/test_json_lib.o


# Generate the json.o build rule for this program
#
# runs `define BUILD_JSON_TEST` macro from json.mk and replaces $(1) with
#     $(JSON_TEST_BUILD) and $(2) with $(CPPFLAGS_JSON_TEST)
# `$(eval ...)` takes the generated Makefile code and adds it to the
#     current Makefile, as if you had written it yourself..
#$(eval $(call BUILD_JSON_TEST,$(JSON_TEST_BUILD),$(CPPFLAGS_JSON_TEST)))


# Create objects from C++ sources
$(JSON_TEST_BUILD)/%.o: src/unit_test/%.cpp
	@mkdir -p $(@D)
	$(CXX) -c $< $(CPPFLAGS_JSON_TEST) $(CXXFLAGS) -o $@


# Build the final executable with all object
json_lib_test: $(JSON_TEST_OBJ)
ifeq ($(PLATFORM),WINDOWS)
	$(CXX) $(LDFLAGS) $^ $(LDLIBS) -o $@.exe
else ifeq ($(PLATFORM),MAC)
	$(CXX) $(LDFLAGS) $^ $(LDLIBS) -o $@
else
	$(CXX) $(LDFLAGS) $^ $(LDLIBS) -o $@
endif

