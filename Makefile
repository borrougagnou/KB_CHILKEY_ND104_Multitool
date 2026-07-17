## COMPILER
CC      = gcc
CXX     = g++
NAME    = myHIDprogram

CFLAGS  =  -Isrc/external/hidapi
CFLAGS  += -Wextra -Wall -Werror


# COMMON OBJECTS
OBJ_COMMON = main_clock.o clock_update.o
OBJ_LINUX  = hid.o
OBJ_WIN    = hid.o
OBJ_MAC    = hid.o
OBJ = $(OBJ_COMMON)

# PLATFORM DETECTION + OBJECT PER PLATFORM
ifeq ($(OS),Windows_NT)
	PLATFORM = WINDOWS
	OBJ += $(OBJ_WIN)
else
	UNAME_S := $(shell uname -s)

	ifeq ($(UNAME_S),Linux)
		PLATFORM = LINUX
		OBJ += $(OBJ_LINUX)
	endif

	ifeq ($(UNAME_S),Darwin)
		PLATFORM = MAC
		OBJ += $(OBJ_MAC)
	endif
endif


# BUILD PART
all: $(NAME)

# Create an object of the C library (HIDAPI)
hid.o:
ifeq ($(PLATFORM),WINDOWS)
	$(CC) -c src/external/hidapi/windows/hid.c -o $@ $(CFLAGS)
else ifeq ($(PLATFORM),MAC)
	$(CC) -c src/external/hidapi/mac/hid.c -o $@ $(CFLAGS)
else
	$(CC) -c src/external/hidapi/libusb/hid.c -I/usr/include/libusb-1.0 -o $@ $(CFLAGS)
endif

# Create objects from C++ sources
%.o: src/%.cpp
	@echo -e '==> $(PLATFORM) Detected'
	$(CXX) -c $< $(CXXFLAGS) -o $@

# Build the final executable with all object
$(NAME): $(OBJ)
ifeq ($(PLATFORM),WINDOWS)
	$(CXX) $^ -o $@.exe -lhid
else ifeq ($(PLATFORM),MAC)
	$(CXX) $^ -o $@ -framework IOKit -framework CoreFoundation
else
	$(CXX) $^ -o $@ -lusb-1.0
endif


# Clean at the end
clean:
	rm -f *.o $(NAME) $(NAME).exe


# RTFM
.PHONY: all clean

