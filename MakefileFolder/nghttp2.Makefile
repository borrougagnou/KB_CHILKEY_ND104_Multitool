# MakefileFolder/nghttp2.Makefile

## LAST EXISTING VERSION:  nghttp2-1.70.0.tar.gz
## VERSION ON THE PROGRAM: nghttp2-1.64.0.tar.gz
## RELEASE PAGE: https://github.com/nghttp2/nghttp2/releases
## VERSION USED: https://github.com/nghttp2/nghttp2/releases/tag/v1.64.0
## DOWNLOAD URL: https://github.com/nghttp2/nghttp2/releases/download/v1.64.0/nghttp2-1.64.0.tar.gz

SHELL := /bin/sh

.DEFAULT_GOAL := all

THIS_MAKEFILE := $(abspath $(firstword $(MAKEFILE_LIST)))

# ==================================================================
# Global variables
# ==================================================================

NGHTTP2_VERSION := 1.64.0

PROJECT_ROOT    ?= $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
EXTERNAL_ROOT   ?= $(PROJECT_ROOT)/src/external
BUILD_ROOT      ?= $(PROJECT_ROOT)/build/external

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
# nghttp2 paths
# ==================================================================

SRC_DIR     := $(EXTERNAL_ROOT)/source/nghttp2-extracted/nghttp2-$(NGHTTP2_VERSION)
INSTALL_DIR := $(EXTERNAL_ROOT)/nghttp2/$(PLATFORM_DIR)
BUILD_DIR   := $(BUILD_ROOT)/$(PLATFORM_DIR)/nghttp2

REQUIRED_HEADER := $(INSTALL_DIR)/include/nghttp2/nghttp2.h
REQUIRED_LIB    := $(INSTALL_DIR)/lib/libnghttp2.a

# ==================================================================
# Platform flags
# ==================================================================

PLATFORM_CFLAGS :=
PLATFORM_LDFLAGS :=

ifeq ($(PLATFORM_DIR),Windows-x32)
PLATFORM_CFLAGS += -m32
PLATFORM_LDFLAGS += -m32
endif

ifeq ($(PLATFORM_DIR),Windows-x64)
PLATFORM_CFLAGS += -m64
PLATFORM_LDFLAGS += -m64
endif

ifeq ($(PLATFORM_DIR),Mac)
ifeq ($(UNAME_M),arm64)
PLATFORM_CFLAGS += -arch arm64
PLATFORM_LDFLAGS += -arch arm64
else
PLATFORM_CFLAGS += -arch x86_64
PLATFORM_LDFLAGS += -arch x86_64
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
		echo "nghttp2 already installed for $(PLATFORM_DIR): $(INSTALL_DIR)"; \
	else \
		echo "nghttp2 missing for $(PLATFORM_DIR). Building..."; \
		$(MAKE) -f "$(THIS_MAKEFILE)" install; \
	fi

check-source:
	@if [ -f "$(SRC_DIR)/configure" ]; then \
		echo "OK: nghttp2 source found: $(SRC_DIR)/configure"; \
	else \
		echo "ERROR: nghttp2 source not found."; \
		echo "Expected file:"; \
		echo "  $(SRC_DIR)/configure"; \
		echo ""; \
		echo "Download nghttp2 $(NGHTTP2_VERSION) and extract it so that file exists."; \
		exit 1; \
	fi

check-install:
	@echo "nghttp2 install directory: $(INSTALL_DIR)"
	@test -f "$(REQUIRED_HEADER)" && echo "[OK HEADER]: $(REQUIRED_HEADER)" || echo "[MISSING HEADER]: $(REQUIRED_HEADER)"
	@test -f "$(REQUIRED_LIB)"    && echo "[OK LIB]: $(REQUIRED_LIB)"       || echo "[MISSING LIB]: $(REQUIRED_LIB)"

compile: check-source
	$(RM_BUILD)
	mkdir -p "$(BUILD_DIR)"
	cp -a "$(SRC_DIR)" "$(BUILD_DIR)/src"

	cd "$(BUILD_DIR)/src" && \
	CC="$(CC)" \
	AR="$(AR)" \
	RANLIB="$(RANLIB)" \
	CFLAGS="$(PLATFORM_CFLAGS)" \
	LDFLAGS="$(PLATFORM_LDFLAGS)" \
	./configure \
		--prefix="$(INSTALL_DIR)" \
		--enable-lib-only \
		--disable-shared \
		--enable-static

	cd "$(BUILD_DIR)/src" && \
	$(MAKE) -j$(JOBS)

install: compile
	cd "$(BUILD_DIR)/src" && \
	$(MAKE) install

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
	@echo "NGHTTP2_VERSION = $(NGHTTP2_VERSION)"
	@echo "PLATFORM_DIR    = $(PLATFORM_DIR)"
	@echo "SRC_DIR         = $(SRC_DIR)"
	@echo "BUILD_DIR       = $(BUILD_DIR)"
	@echo "INSTALL_DIR     = $(INSTALL_DIR)"
	@echo "REQUIRED_HEADER = $(REQUIRED_HEADER)"
	@echo "REQUIRED_LIB    = $(REQUIRED_LIB)"

.PHONY: all check-source check-install compile install rebuild clean-build clean-install clean print-vars

