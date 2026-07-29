include MakefileFolder/base.mk
include MakefileFolder/hidapi.mk


########################
# IMPORTANT ABOUT cURL #
########################
# FIRST YOU NEED TO INSTALL: pkg-config
# the cURL Library should be executed FIRST and SEPARATELY from this Makefile,
# here's how to do it:
# - Check if you have downloaded/extracted source first with:
#     `make -f Makefile.deps check-source`
# - when all are downloaded, build:
#     `make -f Makefile.deps`
# - when the build is finished:
#     `make -f Makefile.deps check-install`
# Done 

#############
# UNIT_TEST #
#############
# We will test here if external libraries are working well:

### be sure to have config.json:
include MakefileFolder/test_json.mk

# be sure internet is working:
include MakefileFolder/test_curl.mk
################


#PROGRAM
include MakefileFolder/clock_update.mk
#include MakefileFolder/weather_update.mk
#include MakefileFolder/picture_upload.mk

# If one of the .mk files defines a rule before "`all:`", Make program may choose that as the default goal.
# To prevent that explicitly set .DEFAULT_GOAL. (https://www.gnu.org/software/make/manual/html_node/Goals.html)
.DEFAULT_GOAL := all

all: $(PROGRAMS)


clean:
	rm -rf build
	rm -f $(PROGRAMS)
	rm -f $(PROGRAMS:%=%.exe)


.PHONY: all clean

