# MakefileFolder/openssl.Makefile

## LAST EXISTING VERSION:  openssl-4.0.1.tar.gz
## VERSION ON THE PROGRAM: openssl-1.1.1w.tar.gz
## RELEASE PAGE: https://github.com/openssl/openssl/releases
## VERSION USED: https://github.com/openssl/openssl/releases/tag/OpenSSL_1_1_1w
## DOWNLOAD URL: https://github.com/openssl/openssl/releases/download/OpenSSL_1_1_1w/openssl-1.1.1w.tar.gz

SHELL := /bin/sh

.DEFAULT_GOAL := all

THIS_MAKEFILE := $(abspath $(firstword $(MAKEFILE_LIST)))

# ==================================================================
# Global variables
# ==================================================================

OPENSSL_VERSION := 1.1.1w

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
# OpenSSL paths
# ==================================================================

SRC_DIR     := $(EXTERNAL_ROOT)/source/openssl-extracted/openssl-$(OPENSSL_VERSION)
INSTALL_DIR := $(EXTERNAL_ROOT)/openssl/$(PLATFORM_DIR)
BUILD_DIR   := $(BUILD_ROOT)/$(PLATFORM_DIR)/openssl

REQUIRED_HEADER     := $(INSTALL_DIR)/include/openssl/ssl.h
REQUIRED_LIB_SSL    := $(INSTALL_DIR)/lib/libssl.a
REQUIRED_LIB_CRYPTO := $(INSTALL_DIR)/lib/libcrypto.a

# ==================================================================
# OpenSSL target configuration
# ==================================================================

OPENSSL_TARGET :=
OPENSSL_EXTRA_CONFIG :=
OPENSSL_CROSS_FLAG := $(if $(CROSS_PREFIX),--cross-compile-prefix=$(CROSS_PREFIX),)

ifeq ($(PLATFORM_DIR),Windows-x32)
OPENSSL_TARGET := mingw
OPENSSL_EXTRA_CONFIG += -D_WIN32_WINNT=0x0501 -DWINVER=0x0501
endif

ifeq ($(PLATFORM_DIR),Windows-x64)
OPENSSL_TARGET := mingw64
OPENSSL_EXTRA_CONFIG += -D_WIN32_WINNT=0x0601 -DWINVER=0x0601
endif

ifeq ($(PLATFORM_DIR),Linux)
ifeq ($(UNAME_M),aarch64)
OPENSSL_TARGET := linux-aarch64
else ifeq ($(UNAME_M),arm64)
OPENSSL_TARGET := linux-aarch64
else ifeq ($(UNAME_M),i686)
OPENSSL_TARGET := linux-x86
else
OPENSSL_TARGET := linux-x86_64
endif
endif

ifeq ($(PLATFORM_DIR),Mac)
ifeq ($(UNAME_M),arm64)
OPENSSL_TARGET := darwin64-arm64-cc
else
OPENSSL_TARGET := darwin64-x86_64-cc
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
	@if [ -f "$(REQUIRED_HEADER)" ] && [ -f "$(REQUIRED_LIB_SSL)" ] && [ -f "$(REQUIRED_LIB_CRYPTO)" ]; then \
		echo "OpenSSL already installed for $(PLATFORM_DIR): $(INSTALL_DIR)"; \
	else \
		echo "OpenSSL missing for $(PLATFORM_DIR). Building..."; \
		$(MAKE) -f "$(THIS_MAKEFILE)" install; \
	fi

check-source:
	@if [ -f "$(SRC_DIR)/Configure" ]; then \
		echo "OK: OpenSSL source found: $(SRC_DIR)/Configure"; \
	else \
		echo "ERROR: OpenSSL source not found."; \
		echo "Expected file:"; \
		echo "  $(SRC_DIR)/Configure"; \
		echo ""; \
		echo "Download OpenSSL $(OPENSSL_VERSION) and extract it so that file exists."; \
		exit 1; \
	fi

check-install:
	@echo "OpenSSL install directory: $(INSTALL_DIR)"
	@test -f "$(REQUIRED_HEADER)"     && echo "[OK HEADER]: $(REQUIRED_HEADER)"  || echo "[MISSING HEADER]: $(REQUIRED_HEADER)"
	@test -f "$(REQUIRED_LIB_SSL)"    && echo "[OK LIB]: $(REQUIRED_LIB_SSL)"    || echo "[MISSING LIB]: $(REQUIRED_LIB_SSL)"
	@test -f "$(REQUIRED_LIB_CRYPTO)" && echo "[OK LIB]: $(REQUIRED_LIB_CRYPTO)" || echo "[MISSING LIB]: $(REQUIRED_LIB_CRYPTO)"

compile: check-source
	$(RM_BUILD)
	mkdir -p "$(BUILD_DIR)"
	cp -a "$(SRC_DIR)" "$(BUILD_DIR)/src"

	cd "$(BUILD_DIR)/src" && \
	perl ./Configure $(OPENSSL_TARGET) \
		$(OPENSSL_CROSS_FLAG) \
		no-shared \
		no-asm \
		no-tests \
		--prefix="$(INSTALL_DIR)" \
		--openssldir="$(INSTALL_DIR)/ssl" \
		$(OPENSSL_EXTRA_CONFIG) && \
	$(MAKE) -j$(JOBS)

install: compile
	cd "$(BUILD_DIR)/src" && \
	$(MAKE) install_sw

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
	@echo "OPENSSL_VERSION     = $(OPENSSL_VERSION)"
	@echo "PLATFORM_DIR        = $(PLATFORM_DIR)"
	@echo "SRC_DIR             = $(SRC_DIR)"
	@echo "BUILD_DIR           = $(BUILD_DIR)"
	@echo "INSTALL_DIR         = $(INSTALL_DIR)"
	@echo "OPENSSL_TARGET      = $(OPENSSL_TARGET)"
	@echo "REQUIRED_HEADER     = $(REQUIRED_HEADER)"
	@echo "REQUIRED_LIB_SSL    = $(REQUIRED_LIB_SSL)"
	@echo "REQUIRED_LIB_CRYPTO = $(REQUIRED_LIB_CRYPTO)"

.PHONY: all check-source check-install compile install rebuild clean-build clean-install clean print-vars
