# This Makefile require 2 arguments, the build directory of the program,
# and the HID include (-Isrc/external/hidapi):
#   $(eval $(call BUILD_HID,<build_directory>,<hid_cppflags>))

define BUILD_HID

$(1)/hid.o:
	@mkdir -p $$(@D)

# Create an object of the C library (HIDAPI)
ifeq ($(PLATFORM),WINDOWS)
	$$(CC) -c src/external/hidapi/windows/hid.c $$(CFLAGS) $(2) -o $$@
else ifeq ($(PLATFORM),MAC)
	$$(CC) -c src/external/hidapi/mac/hid.c     $$(CFLAGS) $(2) -o $$@
else
	$$(CC) -c src/external/hidapi/libusb/hid.c  -I/usr/include/libusb-1.0 $$(CFLAGS) $(2) -o $$@
endif

endef

