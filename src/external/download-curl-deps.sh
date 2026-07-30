#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd -P)"
SOURCE_ROOT="${SOURCE_ROOT:-$SCRIPT_DIR/source}"


OPENSSL_VERSION="${OPENSSL_VERSION:-1.1.1w}"
CURL_VERSION="${CURL_VERSION:-7.77.0}"
ZLIB_VERSION="${ZLIB_VERSION:-1.3.1}"
BROTLI_VERSION="${BROTLI_VERSION:-1.1.0}"
ZSTD_VERSION="${ZSTD_VERSION:-1.5.6}"
NGHTTP2_VERSION="${NGHTTP2_VERSION:-1.64.0}"


if ! command -v curl >/dev/null 2>&1; then
	echo "ERROR: curl is required by this script."
	exit 1
fi

if ! command -v tar >/dev/null 2>&1; then
	echo "ERROR: tar is required by this script."
	exit 1
fi

echo "Script directory: $SCRIPT_DIR"
echo "Source root:      $SOURCE_ROOT"


download_extract() {
	name="$1"
	url="$2"
	dest="$3"
	check="$4"

	if [ "${FORCE_DOWNLOAD:-0}" = "1" ]; then
		echo "FORCE_DOWNLOAD=1, removing: $dest"
		rm -rf "$dest"
	fi

	mkdir -p "$dest"

	if [ -f "$dest/$check" ]; then
		echo "Already present: $dest/$check"
		return 0
	fi

	tmpfile="$(mktemp)"

	echo "Downloading $name from: $url"
	curl -fL --retry 3 -o "$tmpfile" "$url"

	echo "Extracting $name into: $dest"
	tar -xf "$tmpfile" -C "$dest"

	rm -f "$tmpfile"

	if [ ! -f "$dest/$check" ]; then
		echo "ERROR: after extracting $name, expected file not found:"
		echo "  $dest/$check"
		exit 1
	fi

	echo "OK: $name source ready"
}

# ==================================================================
# Download sources
# ==================================================================

download_extract \
	"openssl" \
	"https://github.com/openssl/openssl/releases/download/OpenSSL_1_1_1w/openssl-1.1.1w.tar.gz" \
	"${SOURCE_ROOT}/openssl-extracted" \
	"openssl-${OPENSSL_VERSION}/Configure"

download_extract \
	"curl" \
	"https://github.com/curl/curl/releases/download/curl-7_77_0/curl-7.77.0.tar.gz" \
	"${SOURCE_ROOT}/curl-extracted" \
	"curl-${CURL_VERSION}/configure"

download_extract \
	"zlib" \
	"https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/zlib-${ZLIB_VERSION}.tar.gz" \
	"${SOURCE_ROOT}/zlib-extracted" \
	"zlib-${ZLIB_VERSION}/configure"

download_extract \
	"brotli" \
	"https://github.com/google/brotli/archive/refs/tags/v${BROTLI_VERSION}.tar.gz" \
	"${SOURCE_ROOT}/brotli-extracted" \
	"brotli-${BROTLI_VERSION}/CMakeLists.txt"

download_extract \
	"zstd" \
	"https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/zstd-${ZSTD_VERSION}.tar.gz" \
	"${SOURCE_ROOT}/zstd-extracted" \
	"zstd-${ZSTD_VERSION}/lib/zstd.h"

download_extract \
	"nghttp2" \
	"https://github.com/nghttp2/nghttp2/releases/download/v${NGHTTP2_VERSION}/nghttp2-${NGHTTP2_VERSION}.tar.gz" \
	"${SOURCE_ROOT}/nghttp2-extracted" \
	"nghttp2-${NGHTTP2_VERSION}/configure"

echo "All dependency sources are ready."
