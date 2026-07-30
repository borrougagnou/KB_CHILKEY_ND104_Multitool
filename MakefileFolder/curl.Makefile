# MakefileFolder/curl.Makefile

## LAST EXISTING VERSION:  curl-8.21.0.tar.gz
## VERSION ON THE PROGRAM: curl-7.77.0.tar.gz
## RELEASE PAGE: https://github.com/curl/curl/releases
## VERSION USED: https://github.com/curl/curl/releases/tag/curl-7_77_0
## DOWNLOAD URL: https://github.com/curl/curl/releases/download/curl-7_77_0/curl-7.77.0.tar.gz

SHELL := /bin/sh

HASH := \#

.DEFAULT_GOAL := all

THIS_MAKEFILE := $(abspath $(firstword $(MAKEFILE_LIST)))

# ==================================================================
# Global variables
# ==================================================================

CURL_VERSION  := 7.77.0

PROJECT_ROOT  ?= $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
EXTERNAL_ROOT ?= $(PROJECT_ROOT)/src/external
BUILD_ROOT    ?= $(PROJECT_ROOT)/build/external

CROSS_PREFIX ?=
CC := $(CROSS_PREFIX)gcc
AR := $(CROSS_PREFIX)ar
RANLIB := $(CROSS_PREFIX)ranlib

# ------------------------------------------------------------------
# Optional dependencies
# ------------------------------------------------------------------

ENABLE_OPENSSL ?= 1
ENABLE_ZLIB    ?= 1
ENABLE_BROTLI  ?= 1
ENABLE_ZSTD    ?= 1
ENABLE_NGHTTP2 ?= 1

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
# curl paths
# ==================================================================

SRC_DIR     := $(EXTERNAL_ROOT)/source/curl-extracted/curl-$(CURL_VERSION)
INSTALL_DIR := $(EXTERNAL_ROOT)/curl/$(PLATFORM_DIR)
BUILD_DIR   := $(BUILD_ROOT)/$(PLATFORM_DIR)/curl

REQUIRED_HEADER := $(INSTALL_DIR)/include/curl/curl.h
REQUIRED_LIB    := $(INSTALL_DIR)/lib/libcurl.a

# ==================================================================
# Dependency install directories
# ==================================================================

OPENSSL_INSTALL_DIR := $(EXTERNAL_ROOT)/openssl/$(PLATFORM_DIR)
ZLIB_INSTALL_DIR    := $(EXTERNAL_ROOT)/zlib/$(PLATFORM_DIR)
BROTLI_INSTALL_DIR  := $(EXTERNAL_ROOT)/brotli/$(PLATFORM_DIR)
ZSTD_INSTALL_DIR    := $(EXTERNAL_ROOT)/zstd/$(PLATFORM_DIR)
NGHTTP2_INSTALL_DIR := $(EXTERNAL_ROOT)/nghttp2/$(PLATFORM_DIR)

# ==================================================================
# Dependency required files
# ==================================================================

OPENSSL_REQUIRED_HEADER     := $(OPENSSL_INSTALL_DIR)/include/openssl/ssl.h
OPENSSL_REQUIRED_LIB_SSL    := $(OPENSSL_INSTALL_DIR)/lib/libssl.a
OPENSSL_REQUIRED_LIB_CRYPTO := $(OPENSSL_INSTALL_DIR)/lib/libcrypto.a

ZLIB_REQUIRED_HEADER := $(ZLIB_INSTALL_DIR)/include/zlib.h
ZLIB_REQUIRED_LIB    := $(ZLIB_INSTALL_DIR)/lib/libz.a

BROTLI_REQUIRED_HEADER := $(BROTLI_INSTALL_DIR)/include/brotli/decode.h
BROTLI_REQUIRED_LIB    := $(BROTLI_INSTALL_DIR)/lib/libbrotlidec.a

ZSTD_REQUIRED_HEADER := $(ZSTD_INSTALL_DIR)/include/zstd.h
ZSTD_REQUIRED_LIB    := $(ZSTD_INSTALL_DIR)/lib/libzstd.a

NGHTTP2_REQUIRED_HEADER := $(NGHTTP2_INSTALL_DIR)/include/nghttp2/nghttp2.h
NGHTTP2_REQUIRED_LIB    := $(NGHTTP2_INSTALL_DIR)/lib/libnghttp2.a

# ==================================================================
# Platform flags
# ==================================================================

PLATFORM_CPPFLAGS :=
PLATFORM_LDFLAGS :=
PLATFORM_LIBS :=

CURL_HOST :=
CURL_EXTRA_CONFIG :=

ifeq ($(PLATFORM_DIR),Windows-x32)
PLATFORM_CPPFLAGS += -m32 -D_WIN32_WINNT=0x0501 -DWINVER=0x0501 -DWIN32_LEAN_AND_MEAN
PLATFORM_LDFLAGS  += -m32 -static -static-libgcc -static-libstdc++ \
	-Wl,--major-os-version,5 \
	-Wl,--minor-os-version,1 \
	-Wl,--major-subsystem-version,5 \
	-Wl,--minor-subsystem-version,1

PLATFORM_LIBS += -lws2_32 -lcrypt32 -lgdi32 -ladvapi32 -luser32

CURL_HOST := --host=i686-w64-mingw32
CURL_BUILD := --build=i686-w64-mingw32
CURL_EXTRA_CONFIG += --disable-threaded-resolver

CURL_CONF_CACHE := \
ac_cv_header_windows_h=yes \
ac_cv_header_winsock2_h=yes \
ac_cv_func_ioctlsocket=yes \
ac_cv_func_connect=yes \
ac_cv_func_socket=yes \
ac_cv_func_select=yes \
ac_cv_func_recv=yes \
ac_cv_func_send=yes \
ac_cv_func_getpeername=yes \
ac_cv_func_getsockname=yes
endif

ifeq ($(PLATFORM_DIR),Windows-x64)
PLATFORM_CPPFLAGS += -m64 -D_WIN32_WINNT=0x0601 -DWINVER=0x0601 -DWIN32_LEAN_AND_MEAN
PLATFORM_LDFLAGS += -m64 -static -static-libgcc -static-libstdc++ \
	-Wl,--major-os-version,6 \
	-Wl,--minor-os-version,1 \
	-Wl,--major-subsystem-version,6 \
	-Wl,--minor-subsystem-version,1

PLATFORM_LIBS += -lws2_32 -lcrypt32 -lgdi32 -ladvapi32 -luser32

CURL_HOST := --host=x86_64-w64-mingw32
CURL_BUILD := --build=x86_64-w64-mingw32

CURL_CONF_CACHE := \
ac_cv_header_windows_h=yes \
ac_cv_header_winsock2_h=yes \
ac_cv_func_ioctlsocket=yes \
ac_cv_func_connect=yes \
ac_cv_func_socket=yes \
ac_cv_func_select=yes \
ac_cv_func_recv=yes \
ac_cv_func_send=yes \
ac_cv_func_getpeername=yes \
ac_cv_func_getsockname=yes
endif

ifeq ($(PLATFORM_DIR),Linux)
PLATFORM_CPPFLAGS += -fPIC
PLATFORM_LDFLAGS += -static-libgcc -static-libstdc++
PLATFORM_LIBS += -lpthread -ldl
endif

ifeq ($(PLATFORM_DIR),Mac)
ifeq ($(UNAME_M),arm64)
PLATFORM_CPPFLAGS += -arch arm64
PLATFORM_LDFLAGS += -arch arm64
CURL_HOST := --host=aarch64-apple-darwin
else
PLATFORM_CPPFLAGS += -arch x86_64
PLATFORM_LDFLAGS += -arch x86_64
CURL_HOST := --host=x86_64-apple-darwin
endif

PLATFORM_LDFLAGS += -framework CoreFoundation -framework Security
PLATFORM_LIBS += -lpthread -ldl
endif

# ==================================================================
# Dependency flags
# ==================================================================

DEP_CPPFLAGS :=
DEP_LDFLAGS :=
DEP_LIBS :=
CURL_CONFIG_FLAGS :=
PKG_CONFIG_DIRS :=

# ------------------------------------------------------------------
# OpenSSL
# ------------------------------------------------------------------

ifeq ($(ENABLE_OPENSSL),1)
CURL_CONFIG_FLAGS += --with-openssl="$(OPENSSL_INSTALL_DIR)"
DEP_CPPFLAGS += -I$(OPENSSL_INSTALL_DIR)/include
DEP_LDFLAGS += -L$(OPENSSL_INSTALL_DIR)/lib
PKG_CONFIG_DIRS += $(OPENSSL_INSTALL_DIR)/lib/pkgconfig
else
CURL_CONFIG_FLAGS += --without-ssl
endif

# ------------------------------------------------------------------
# zlib
# ------------------------------------------------------------------

ifeq ($(ENABLE_ZLIB),1)
CURL_CONFIG_FLAGS += --with-zlib="$(ZLIB_INSTALL_DIR)"
DEP_CPPFLAGS += -I$(ZLIB_INSTALL_DIR)/include
DEP_LDFLAGS += -L$(ZLIB_INSTALL_DIR)/lib
DEP_LIBS += -lz
PKG_CONFIG_DIRS += $(ZLIB_INSTALL_DIR)/lib/pkgconfig
else
CURL_CONFIG_FLAGS += --without-zlib
endif

# ------------------------------------------------------------------
# brotli
# ------------------------------------------------------------------

ifeq ($(ENABLE_BROTLI),1)
CURL_CONFIG_FLAGS += --with-brotli
DEP_CPPFLAGS += -I$(BROTLI_INSTALL_DIR)/include
DEP_LDFLAGS += -L$(BROTLI_INSTALL_DIR)/lib
DEP_LIBS += -lbrotlidec -lbrotlicommon
PKG_CONFIG_DIRS += $(BROTLI_INSTALL_DIR)/lib/pkgconfig
else
CURL_CONFIG_FLAGS += --without-brotli
endif

# ------------------------------------------------------------------
# zstd
# ------------------------------------------------------------------

ifeq ($(ENABLE_ZSTD),1)
CURL_CONFIG_FLAGS += --with-zstd
DEP_CPPFLAGS += -I$(ZSTD_INSTALL_DIR)/include
DEP_LDFLAGS += -L$(ZSTD_INSTALL_DIR)/lib
DEP_LIBS += -lzstd
PKG_CONFIG_DIRS += $(ZSTD_INSTALL_DIR)/lib/pkgconfig
else
CURL_CONFIG_FLAGS += --without-zstd
endif

# ------------------------------------------------------------------
# nghttp2
# ------------------------------------------------------------------

ifeq ($(ENABLE_NGHTTP2),1)
CURL_CONFIG_FLAGS += --with-nghttp2="$(NGHTTP2_INSTALL_DIR)"
DEP_CPPFLAGS += -I$(NGHTTP2_INSTALL_DIR)/include
DEP_LDFLAGS += -L$(NGHTTP2_INSTALL_DIR)/lib
DEP_LIBS += -lnghttp2
PKG_CONFIG_DIRS += $(NGHTTP2_INSTALL_DIR)/lib/pkgconfig
else
CURL_CONFIG_FLAGS += --without-nghttp2
endif

# ------------------------------------------------------------------
# PKG_CONFIG_PATH helper
# ------------------------------------------------------------------

EMPTY :=
SPACE := $(EMPTY) $(EMPTY)
PKG_CONFIG_PATH_VALUE := $(subst $(SPACE),:,$(strip $(PKG_CONFIG_DIRS)))

# ------------------------------------------------------------------
# Final curl flags
# ------------------------------------------------------------------

CURL_CPPFLAGS := $(PLATFORM_CPPFLAGS) $(DEP_CPPFLAGS)
CURL_CFLAGS   := $(PLATFORM_CPPFLAGS)
CURL_LDFLAGS  := $(PLATFORM_LDFLAGS) $(DEP_LDFLAGS)
CURL_LIBS     := $(PLATFORM_LIBS) $(DEP_LIBS)

# ==================================================================
# Remove commands
# ==================================================================

RM_BUILD   := rm -rf "$(BUILD_DIR)"
RM_INSTALL := rm -rf "$(INSTALL_DIR)"
RM_ALL     := rm -rf "$(BUILD_DIR)" "$(INSTALL_DIR)"

# ==================================================================
# Targets
# ==================================================================

all: check-deps
	@if [ -f "$(REQUIRED_HEADER)" ] && [ -f "$(REQUIRED_LIB)" ]; then \
		echo "curl already installed for $(PLATFORM_DIR): $(INSTALL_DIR)"; \
		echo "If you changed ENABLE_* options, run: make -f MakefileFolder/curl.Makefile rebuild"; \
	else \
		echo "curl missing for $(PLATFORM_DIR). Building..."; \
		$(MAKE) -f "$(THIS_MAKEFILE)" install; \
	fi

check-source:
	@if [ -f "$(SRC_DIR)/configure" ]; then \
		echo "OK: curl source found: $(SRC_DIR)/configure"; \
	else \
		echo "ERROR: curl source not found."; \
		echo "Expected file:"; \
		echo "  $(SRC_DIR)/configure"; \
		echo ""; \
		echo "Download curl $(CURL_VERSION) and extract it so that file exists."; \
		exit 1; \
	fi

check-deps:
ifeq ($(ENABLE_OPENSSL),1)
	@test -f "$(OPENSSL_REQUIRED_HEADER)" || { \
		echo "ERROR: OpenSSL header not found."; \
		echo "Expected: $(OPENSSL_REQUIRED_HEADER)"; \
		echo "Build OpenSSL first."; \
		exit 1; \
	}
	@test -f "$(OPENSSL_REQUIRED_LIB_SSL)" || { \
		echo "ERROR: OpenSSL libssl not found."; \
		echo "Expected: $(OPENSSL_REQUIRED_LIB_SSL)"; \
		echo "Build OpenSSL first."; \
		exit 1; \
	}
	@test -f "$(OPENSSL_REQUIRED_LIB_CRYPTO)" || { \
		echo "ERROR: OpenSSL libcrypto not found."; \
		echo "Expected: $(OPENSSL_REQUIRED_LIB_CRYPTO)"; \
		echo "Build OpenSSL first."; \
		exit 1; \
	}
endif

ifeq ($(ENABLE_ZLIB),1)
	@test -f "$(ZLIB_REQUIRED_HEADER)" || { \
		echo "ERROR: zlib header not found."; \
		echo "Expected: $(ZLIB_REQUIRED_HEADER)"; \
		echo "Build zlib first."; \
		exit 1; \
	}
	@test -f "$(ZLIB_REQUIRED_LIB)" || { \
		echo "ERROR: zlib library not found."; \
		echo "Expected: $(ZLIB_REQUIRED_LIB)"; \
		echo "Build zlib first."; \
		exit 1; \
	}
endif

ifeq ($(ENABLE_BROTLI),1)
	@test -f "$(BROTLI_REQUIRED_HEADER)" || { \
		echo "ERROR: brotli header not found."; \
		echo "Expected: $(BROTLI_REQUIRED_HEADER)"; \
		echo "Build brotli first."; \
		exit 1; \
	}
	@test -f "$(BROTLI_REQUIRED_LIB)" || { \
		echo "ERROR: brotli library not found."; \
		echo "Expected: $(BROTLI_REQUIRED_LIB)"; \
		echo "Build brotli first."; \
		exit 1; \
	}
endif

ifeq ($(ENABLE_ZSTD),1)
	@test -f "$(ZSTD_REQUIRED_HEADER)" || { \
		echo "ERROR: zstd header not found."; \
		echo "Expected: $(ZSTD_REQUIRED_HEADER)"; \
		echo "Build zstd first."; \
		exit 1; \
	}
	@test -f "$(ZSTD_REQUIRED_LIB)" || { \
		echo "ERROR: zstd library not found."; \
		echo "Expected: $(ZSTD_REQUIRED_LIB)"; \
		echo "Build zstd first."; \
		exit 1; \
	}
endif

ifeq ($(ENABLE_NGHTTP2),1)
	@test -f "$(NGHTTP2_REQUIRED_HEADER)" || { \
		echo "ERROR: nghttp2 header not found."; \
		echo "Expected: $(NGHTTP2_REQUIRED_HEADER)"; \
		echo "Build nghttp2 first."; \
		exit 1; \
	}
	@test -f "$(NGHTTP2_REQUIRED_LIB)" || { \
		echo "ERROR: nghttp2 library not found."; \
		echo "Expected: $(NGHTTP2_REQUIRED_LIB)"; \
		echo "Build nghttp2 first."; \
		exit 1; \
	}
endif

check-install:
	@echo "curl install directory: $(INSTALL_DIR)"
	@test -f "$(REQUIRED_HEADER)" && echo "[OK HEADER]: $(REQUIRED_HEADER)" || echo "[MISSING HEADER]: $(REQUIRED_HEADER)"
	@test -f "$(REQUIRED_LIB)"    && echo "[OK LIB]: $(REQUIRED_LIB)"       || echo "[MISSING LIB]: $(REQUIRED_LIB)"

compile: check-deps check-source
	$(RM_BUILD)
	mkdir -p "$(BUILD_DIR)"
	cp -a "$(SRC_DIR)" "$(BUILD_DIR)/src"

	cd "$(BUILD_DIR)/src" && \
	CC="$(CC)" \
	AR="$(AR)" \
	RANLIB="$(RANLIB)" \
	PKG_CONFIG_PATH="$(PKG_CONFIG_PATH_VALUE)" \
	CPPFLAGS="$(CURL_CPPFLAGS)" \
	CFLAGS="$(CURL_CFLAGS)" \
	LDFLAGS="$(CURL_LDFLAGS)" \
	LIBS="$(CURL_LIBS)" \
	$(CURL_CONF_CACHE) ./configure \
		$(CURL_HOST) \
		$(CURL_BUILD) \
		--prefix="$(INSTALL_DIR)" \
		--enable-static \
		--disable-shared \
		$(CURL_CONFIG_FLAGS) \
		--without-libpsl \
		--without-libidn2 \
		--without-librtmp \
		--without-libssh2 \
		--disable-ldap \
		--disable-ldaps \
		--disable-rtsp \
		--disable-telnet \
		--disable-tftp \
		--disable-pop3 \
		--disable-imap \
		--disable-smb \
		--disable-smtp \
		--disable-gopher \
		--disable-dict \
		--disable-ftp \
		--disable-file \
		--disable-manual \
		$(CURL_EXTRA_CONFIG) && \
	case "$(PLATFORM_DIR)" in \
		Windows-*) \
			echo "Patching lib/curl_config.h for Windows sockets"; \
			{ \
				echo "$(HASH)undef  HAVE_WINDOWS_H"; \
				echo "$(HASH)define HAVE_WINDOWS_H 1"; \
				echo "$(HASH)undef  HAVE_WINSOCK2_H"; \
				echo "$(HASH)define HAVE_WINSOCK2_H 1"; \
				echo "$(HASH)undef  HAVE_WS2TCPIP_H"; \
				echo "$(HASH)define HAVE_WS2TCPIP_H 1"; \
				echo "$(HASH)undef  HAVE_IOCTLSOCKET"; \
				echo "$(HASH)define HAVE_IOCTLSOCKET 1"; \
				echo "$(HASH)undef  HAVE_IOCTLSOCKET_FIONBIO"; \
				echo "$(HASH)define HAVE_IOCTLSOCKET_FIONBIO 1"; \
				echo "$(HASH)undef  USE_WINSOCK"; \
				echo "$(HASH)define USE_WINSOCK 1"; \
			} >> lib/curl_config.h; \
			;; \
	esac && \
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
	@echo "CURL_VERSION          = $(CURL_VERSION)"
	@echo "PLATFORM_DIR          = $(PLATFORM_DIR)"
	@echo "SRC_DIR               = $(SRC_DIR)"
	@echo "BUILD_DIR             = $(BUILD_DIR)"
	@echo "INSTALL_DIR           = $(INSTALL_DIR)"
	@echo "ENABLE_OPENSSL        = $(ENABLE_OPENSSL)"
	@echo "ENABLE_ZLIB           = $(ENABLE_ZLIB)"
	@echo "ENABLE_BROTLI         = $(ENABLE_BROTLI)"
	@echo "ENABLE_ZSTD           = $(ENABLE_ZSTD)"
	@echo "ENABLE_NGHTTP2        = $(ENABLE_NGHTTP2)"
	@echo "REQUIRED_HEADER       = $(REQUIRED_HEADER)"
	@echo "REQUIRED_LIB          = $(REQUIRED_LIB)"
	@echo "PKG_CONFIG_PATH_VALUE = $(PKG_CONFIG_PATH_VALUE)"

.PHONY: all check-source check-deps check-install compile install rebuild clean-build clean-install clean print-vars
