include MakefileFolder/base.mk
include MakefileFolder/hidapi.mk

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

