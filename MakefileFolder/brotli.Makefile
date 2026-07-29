# MakefileFolder/brotli.Makefile

## LAST EXISTING VERSION:  brotli-1.2.0.tar.gz (Source code - tar.gz)
## VERSION ON THE PROGRAM: brotli-1.1.0.tar.gz (Source code - tar.gz)
## RELEASE PAGE: https://github.com/google/brotli/releases
## VERSION USED: https://github.com/google/brotli/releases/tag/v1.1.0
## DOWNLOAD URL: https://github.com/google/brotli/archive/refs/tags/v1.1.0.tar.gz

SHELL := /bin/sh

.DEFAULT_GOAL := all

THIS_MAKEFILE := $(abspath $(firstword $(MAKEFILE_LIST)))

# ==================================================================
# Global variables
# ==================================================================

BROTLI_VERSION := 1.1.0

PROJECT_ROOT   ?= $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
EXTERNAL_ROOT  ?= $(PROJECT_ROOT)/src/external
BUILD_ROOT     ?= $(PROJECT_ROOT)/build/external

CROSS_PREFIX ?=
CC := $(CROSS_PREFIX)gcc
AR := $(CROSS_PREFIX)ar
RANLIB := $(CROSS_PREFIX)ranlib

CC_PATH     := $(shell command -v $(CC) 2>/dev/null)
AR_PATH     := $(shell command -v $(AR) 2>/dev/null)
RANLIB_PATH := $(shell command -v $(RANLIB) 2>/dev/null)
MAKE_PATH   := $(shell command -v $(MAKE) 2>/dev/null)

ifeq ($(CC_PATH),)
$(error Cannot find C compiler '$(CC)'. Install gcc or clang.)
endif

ifeq ($(AR_PATH),)
$(error Cannot find archiver '$(AR)'. Install binutils.)
endif

ifeq ($(RANLIB_PATH),)
$(error Cannot find ranlib '$(RANLIB)'. Install binutils.)
endif

ifeq ($(MAKE_PATH),)
MAKE_PATH := $(MAKE)
endif

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

# ------------------------------------------------------------------
# CMake generator
# ------------------------------------------------------------------
# If you use mingw32-make instead of MSYS make on Windows,
# you may need to change this to:
#   CMAKE_GENERATOR ?= MinGW Makefiles
# ------------------------------------------------------------------

ifeq ($(OS),Windows_NT)
CMAKE_GENERATOR ?= MSYS Makefiles
else
CMAKE_GENERATOR ?= Unix Makefiles
endif

# ==================================================================
# Brotli paths
# ==================================================================

SRC_DIR     := $(EXTERNAL_ROOT)/source/brotli-extracted/brotli-$(BROTLI_VERSION)
INSTALL_DIR := $(EXTERNAL_ROOT)/brotli/$(PLATFORM_DIR)
BUILD_DIR   := $(BUILD_ROOT)/$(PLATFORM_DIR)/brotli

REQUIRED_HEADER     := $(INSTALL_DIR)/include/brotli/decode.h
REQUIRED_LIB_COMMON := $(INSTALL_DIR)/lib/libbrotlicommon.a
REQUIRED_LIB_DEC    := $(INSTALL_DIR)/lib/libbrotlidec.a
REQUIRED_LIB_ENC    := $(INSTALL_DIR)/lib/libbrotlienc.a

# ==================================================================
# Platform flags
# ==================================================================

BROTLI_CFLAGS :=
BROTLI_EXE_LINKER_FLAGS :=

ifeq ($(PLATFORM_DIR),Windows-x32)
BROTLI_CFLAGS += -m32 -D_WIN32_WINNT=0x0501 -DWINVER=0x0501 -DWIN32_LEAN_AND_MEAN
BROTLI_EXE_LINKER_FLAGS += -m32 -static -static-libgcc
endif

ifeq ($(PLATFORM_DIR),Windows-x64)
BROTLI_CFLAGS += -m64 -D_WIN32_WINNT=0x0601 -DWINVER=0x0601 -DWIN32_LEAN_AND_MEAN
BROTLI_EXE_LINKER_FLAGS += -m64 -static -static-libgcc
endif

ifeq ($(PLATFORM_DIR),Linux)
BROTLI_CFLAGS += -fPIC
endif

ifeq ($(PLATFORM_DIR),Mac)
ifeq ($(UNAME_M),arm64)
BROTLI_CFLAGS += -arch arm64
BROTLI_EXE_LINKER_FLAGS += -arch arm64
else
BROTLI_CFLAGS += -arch x86_64
BROTLI_EXE_LINKER_FLAGS += -arch x86_64
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
	@if [ -f "$(REQUIRED_HEADER)" ] && [ -f "$(REQUIRED_LIB_COMMON)" ] && [ -f "$(REQUIRED_LIB_DEC)" ] && [ -f "$(REQUIRED_LIB_ENC)" ]; then \
		echo "brotli already installed for $(PLATFORM_DIR): $(INSTALL_DIR)"; \
	else \
		echo "brotli missing for $(PLATFORM_DIR). Building..."; \
		$(MAKE) -f "$(THIS_MAKEFILE)" install; \
	fi

check-source:
	@if [ -f "$(SRC_DIR)/CMakeLists.txt" ]; then \
		echo "OK: brotli source found: $(SRC_DIR)/CMakeLists.txt"; \
	else \
		echo "ERROR: brotli source not found."; \
		echo "Expected file:"; \
		echo "  $(SRC_DIR)/CMakeLists.txt"; \
		echo ""; \
		echo "Download brotli $(BROTLI_VERSION) and extract it so that file exists."; \
		exit 1; \
	fi

check-tools:
	@command -v cmake >/dev/null 2>&1 || { \
		echo "ERROR: cmake is required to build brotli."; \
		echo "Install cmake for your platform."; \
		exit 1; \
	}
	@echo "OK: cmake found"

check-install:
	@echo "brotli install directory: $(INSTALL_DIR)"
	@test -f "$(REQUIRED_HEADER)"     && echo "[OK HEADER]: $(REQUIRED_HEADER)"  || echo "[MISSING HEADER]: $(REQUIRED_HEADER)"
	@test -f "$(REQUIRED_LIB_COMMON)" && echo "[OK LIB]: $(REQUIRED_LIB_COMMON)" || echo "[MISSING LIB]: $(REQUIRED_LIB_COMMON)"
	@test -f "$(REQUIRED_LIB_DEC)"    && echo "[OK LIB]: $(REQUIRED_LIB_DEC)"    || echo "[MISSING LIB]: $(REQUIRED_LIB_DEC)"
	@test -f "$(REQUIRED_LIB_ENC)"    && echo "[OK LIB]: $(REQUIRED_LIB_ENC)"    || echo "[MISSING LIB]: $(REQUIRED_LIB_ENC)"

compile: check-source check-tools
	$(RM_BUILD)
	mkdir -p "$(BUILD_DIR)"
	cp -a "$(SRC_DIR)" "$(BUILD_DIR)/src"

	cd "$(BUILD_DIR)/src" && \
	mkdir -p build && \
	cd build && \
	cmake .. \
		-G "$(CMAKE_GENERATOR)" \
		-DCMAKE_MAKE_PROGRAM="$(MAKE_PATH)" \
		-DCMAKE_BUILD_TYPE=Release \
		-DBUILD_SHARED_LIBS=OFF \
		-DCMAKE_INSTALL_PREFIX="$(INSTALL_DIR)" \
		-DCMAKE_INSTALL_LIBDIR=lib \
		-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
		-DCMAKE_C_COMPILER="$(CC_PATH)" \
		-DCMAKE_AR="$(AR_PATH)" \
		-DCMAKE_RANLIB="$(RANLIB_PATH)" \
		-DCMAKE_C_FLAGS="$(BROTLI_CFLAGS)" \
		-DCMAKE_EXE_LINKER_FLAGS="$(BROTLI_EXE_LINKER_FLAGS)" \
		-DBUILD_TESTING=OFF

	cd "$(BUILD_DIR)/src/build" && \
	$(MAKE) -j$(JOBS)

install: compile
	cd "$(BUILD_DIR)/src/build" && \
	$(MAKE) install

	mkdir -p "$(INSTALL_DIR)/lib/pkgconfig"
	@for suffix in common dec enc; do \
		pc="$(INSTALL_DIR)/lib/pkgconfig/libbrotli$${suffix}.pc"; \
		if [ ! -f "$$pc" ]; then \
			echo "Generating $$pc"; \
			{ \
				echo "prefix=$(INSTALL_DIR)"; \
				echo 'exec_prefix=$${prefix}'; \
				echo 'libdir=$${exec_prefix}/lib'; \
				echo 'includedir=$${prefix}/include'; \
				echo ""; \
				echo "Name: libbrotli$${suffix}"; \
				echo "Description: Brotli $${suffix} library"; \
				echo "Version: $(BROTLI_VERSION)"; \
				if [ "$$suffix" != "common" ]; then \
					echo "Requires: libbrotlicommon"; \
				fi; \
				echo 'Libs: -L$${libdir} -lbrotli'"$$suffix"; \
				echo 'Cflags: -I$${includedir}'; \
			} > "$$pc"; \
		fi; \
	done

rebuild:
	$(RM_ALL)
	$(MAKE) -f "$(THIS_MAKEFILE)" install

clean-build:
	$(RM_BUILD)

clean-install:
	$(RM_INSTALL)

clean:
	$(RM_ALL)

print-vars:
	@echo "BROTLI_VERSION       = $(BROTLI_VERSION)"
	@echo "PLATFORM_DIR         = $(PLATFORM_DIR)"
	@echo "SRC_DIR              = $(SRC_DIR)"
	@echo "BUILD_DIR            = $(BUILD_DIR)"
	@echo "INSTALL_DIR          = $(INSTALL_DIR)"
	@echo "CMAKE_GENERATOR      = $(CMAKE_GENERATOR)"
	@echo "REQUIRED_HEADER      = $(REQUIRED_HEADER)"
	@echo "REQUIRED_LIB_COMMON  = $(REQUIRED_LIB_COMMON)"
	@echo "REQUIRED_LIB_DEC     = $(REQUIRED_LIB_DEC)"
	@echo "REQUIRED_LIB_ENC     = $(REQUIRED_LIB_ENC)"

.PHONY: all check-source check-tools check-install compile install rebuild clean-build clean-install clean print-vars

