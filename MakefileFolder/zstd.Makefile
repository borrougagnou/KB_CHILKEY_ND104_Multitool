# MakefileFolder/zstd.Makefile

## LAST EXISTING VERSION:  zstd-1.5.7.tar.gz 
## VERSION ON THE PROGRAM: zstd-1.5.6.tar.gz
## RELEASE PAGE: https://github.com/facebook/zstd/releases
## VERSION USED: https://github.com/facebook/zstd/releases/tag/v1.5.6
## DOWNLOAD URL: https://github.com/facebook/zstd/releases/download/v1.5.6/zstd-1.5.6.tar.gz

SHELL := /bin/sh

.DEFAULT_GOAL := all

THIS_MAKEFILE := $(abspath $(firstword $(MAKEFILE_LIST)))

# ==================================================================
# Global variables
# ==================================================================

ZSTD_VERSION  := 1.5.6

PROJECT_ROOT  ?= $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
EXTERNAL_ROOT ?= $(PROJECT_ROOT)/src/external
BUILD_ROOT    ?= $(PROJECT_ROOT)/build/external

CROSS_PREFIX ?=
CC := $(CROSS_PREFIX)gcc
AR := $(CROSS_PREFIX)ar
RANLIB := $(CROSS_PREFIX)ranlib

# ==================================================================
# Platform detection
# ==================================================================

UNAME_S :=
UNAME_M :=
PLATFORM_DIR :=

ifeq ($(OS),Windows_NT)
JOBS ?= $(NUMBER_OF_PROCESSORS)

ifeq ($(MSYSTEM),MINGW32)
PLATFORM_DIR := Windows-x32
else ifeq ($(MSYSTEM),MINGW64)
PLATFORM_DIR := Windows-x64
else ifeq ($(MSYSTEM),UCRT64)
PLATFORM_DIR := Windows-x64
else ifeq ($(MSYSTEM),CLANG64)
PLATFORM_DIR := Windows-x64
else ifdef PROCESSOR_ARCHITECTURE
ifeq ($(PROCESSOR_ARCHITECTURE),x86)
PLATFORM_DIR := Windows-x32
else
PLATFORM_DIR := Windows-x64
endif
endif

else
UNAME_S := $(shell uname -s 2>/dev/null)
UNAME_M := $(shell uname -m 2>/dev/null)

ifeq ($(UNAME_S),Darwin)
JOBS ?= $(shell sysctl -n hw.ncpu 2>/dev/null || echo 4)
else
JOBS ?= $(shell nproc 2>/dev/null || echo 4)
endif

ifeq ($(UNAME_S),Linux)
PLATFORM_DIR := Linux
else ifeq ($(UNAME_S),Darwin)
PLATFORM_DIR := Mac
endif
endif

ifeq ($(JOBS),)
JOBS := 4
endif

ifndef PLATFORM_DIR
$(error Cannot detect platform. Use Windows MSYS2 MINGW32/MINGW64, Linux, or macOS.)
endif

# ==================================================================
# zstd paths
# ==================================================================

SRC_DIR     := $(EXTERNAL_ROOT)/source/zstd-extracted/zstd-$(ZSTD_VERSION)
INSTALL_DIR := $(EXTERNAL_ROOT)/zstd/$(PLATFORM_DIR)
BUILD_DIR   := $(BUILD_ROOT)/$(PLATFORM_DIR)/zstd

REQUIRED_HEADER := $(INSTALL_DIR)/include/zstd.h
REQUIRED_LIB    := $(INSTALL_DIR)/lib/libzstd.a

# ==================================================================
# Platform flags
# ==================================================================

PLATFORM_CFLAGS :=

ifeq ($(PLATFORM_DIR),Windows-x32)
PLATFORM_CFLAGS += -m32
endif

ifeq ($(PLATFORM_DIR),Windows-x64)
PLATFORM_CFLAGS += -m64
endif

ifeq ($(PLATFORM_DIR),Mac)
ifeq ($(UNAME_M),arm64)
PLATFORM_CFLAGS += -arch arm64
else
PLATFORM_CFLAGS += -arch x86_64
endif
endif

# ==================================================================
# Remove commands
# ==================================================================

RM_BUILD   := rm -rf "$(BUILD_DIR)"
RM_INSTALL := rm -rf "$(INSTALL_DIR)"
RM_ALL     := rm -rf "$(BUILD_DIR)" "$(INSTALL_DIR)"

# ==================================================================
# Targets
# ==================================================================

all:
	@if [ -f "$(REQUIRED_HEADER)" ] && [ -f "$(REQUIRED_LIB)" ]; then \
		echo "zstd already installed for $(PLATFORM_DIR): $(INSTALL_DIR)"; \
	else \
		echo "zstd missing for $(PLATFORM_DIR). Building..."; \
		$(MAKE) -f "$(THIS_MAKEFILE)" install; \
	fi

check-source:
	@if [ -d "$(SRC_DIR)/lib" ]; then \
		echo "OK: zstd source found: $(SRC_DIR)/lib"; \
	else \
		echo "ERROR: zstd source not found."; \
		echo "Expected directory:"; \
		echo "  $(SRC_DIR)/lib"; \
		echo ""; \
		echo "Download zstd $(ZSTD_VERSION) and extract it so that directory exists."; \
		exit 1; \
	fi

check-install:
	@echo "zstd install directory: $(INSTALL_DIR)"
	@test -f "$(REQUIRED_HEADER)" && echo "[OK HEADER]: $(REQUIRED_HEADER)" || echo "[MISSING HEADER]: $(REQUIRED_HEADER)"
	@test -f "$(REQUIRED_LIB)"    && echo "[OK LIB]: $(REQUIRED_LIB)"       || echo "[MISSING LIB]: $(REQUIRED_LIB)"

compile: check-source
	$(RM_BUILD)
	mkdir -p "$(BUILD_DIR)"
	cp -a "$(SRC_DIR)" "$(BUILD_DIR)/src"

	cd "$(BUILD_DIR)/src/lib" && \
	$(MAKE) libzstd.a \
		CC="$(CC)" \
		AR="$(AR)" \
		CFLAGS="$(PLATFORM_CFLAGS)"

install: compile
	mkdir -p "$(INSTALL_DIR)/include"
	mkdir -p "$(INSTALL_DIR)/lib/pkgconfig"

	cp -a "$(BUILD_DIR)/src/lib/zstd.h" "$(INSTALL_DIR)/include/"
	cp -a "$(BUILD_DIR)/src/lib/zstd_errors.h" "$(INSTALL_DIR)/include/"
	cp -a "$(BUILD_DIR)/src/lib/zdict.h" "$(INSTALL_DIR)/include/"
	cp -a "$(BUILD_DIR)/src/lib/libzstd.a" "$(INSTALL_DIR)/lib/"

	@{ \
		echo "prefix=$(INSTALL_DIR)"; \
		echo 'exec_prefix=$${prefix}'; \
		echo 'libdir=$${exec_prefix}/lib'; \
		echo 'includedir=$${prefix}/include'; \
		echo ""; \
		echo "Name: zstd"; \
		echo "Description: fast lossless compression algorithm library"; \
		echo "URL: https://facebook.github.io/zstd/"; \
		echo "Version: $(ZSTD_VERSION)"; \
		echo 'Libs: -L$${libdir} -lzstd'; \
		echo 'Cflags: -I$${includedir}'; \
	} > "$(INSTALL_DIR)/lib/pkgconfig/libzstd.pc"

rebuild:
	$(RM_ALL)
	$(MAKE) install

clean-build:
	$(RM_BUILD)

clean-install:
	$(RM_INSTALL)

clean:
	$(RM_ALL)

print-vars:
	@echo "ZSTD_VERSION    = $(ZSTD_VERSION)"
	@echo "PLATFORM_DIR    = $(PLATFORM_DIR)"
	@echo "SRC_DIR         = $(SRC_DIR)"
	@echo "BUILD_DIR       = $(BUILD_DIR)"
	@echo "INSTALL_DIR     = $(INSTALL_DIR)"
	@echo "REQUIRED_HEADER = $(REQUIRED_HEADER)"
	@echo "REQUIRED_LIB    = $(REQUIRED_LIB)"

.PHONY: all check-source check-install compile install rebuild clean-build clean-install clean print-vars

