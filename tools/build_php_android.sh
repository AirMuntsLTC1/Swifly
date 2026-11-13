#!/usr/bin/env bash
# Builds a small PHP command-line runtime for Android (arm64) and saves it as
#   build/php-android/out/libphp_cli.so
# It is named lib*.so on purpose: Android unpacks such files next to the app's own
# libraries, and the C++ core (cpp/media_bridge.cpp) runs it from there.
#
# The PHP scripts live in cpp/php/. This script only builds the runtime that runs them.
# It tries to include GD (JPEG and PNG resizing). If that fails it builds PHP without GD
# (photos are then copied instead of resized).
#
# The GitHub workflow turns a failure of this script into a yellow warning, so the APK
# still builds; the app then uses the C++ fallback for photos and videos.
set -euo pipefail

PHP_VER="${PHP_VER:-8.3.14}"
JPEG_VER="${JPEG_VER:-3.0.4}"
PNG_VER="${PNG_VER:-1.6.44}"
API=24
TRIPLE=aarch64-linux-android

NDK="${ANDROID_NDK_LATEST_HOME:-${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}}"
if [ -z "$NDK" ] || [ ! -d "$NDK" ]; then
  echo "Android NDK not found (set ANDROID_NDK_HOME)"; exit 1
fi
TC="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
ROOT="$(pwd)/build/php-android"
PFX="$ROOT/prefix"
OUT="$ROOT/out"
JOBS="$(nproc)"
mkdir -p "$ROOT/src" "$PFX/lib/pkgconfig" "$PFX/include" "$OUT"
cd "$ROOT"
rm -f "$OUT/libphp_cli.so"

export CC="$TC/bin/${TRIPLE}${API}-clang"
export CXX="$TC/bin/${TRIPLE}${API}-clang++"
export AR="$TC/bin/llvm-ar"
export RANLIB="$TC/bin/llvm-ranlib"
export STRIP="$TC/bin/llvm-strip"
export NM="$TC/bin/llvm-nm"
export PKG_CONFIG_PATH="$PFX/lib/pkgconfig:$PFX/lib64/pkgconfig"

# fetch <output> <url> [more urls...]  - tries each address until one works.
fetch() {
  local out="$1"; shift
  [ -s "$out" ] && return 0
  local url
  for url in "$@"; do
    echo "download: $url"
    if curl -fsSL --retry 3 "$url" -o "$out"; then
      [ -s "$out" ] && return 0
    fi
    rm -f "$out"
  done
  echo "could not download $out"
  return 1
}

# libpng's pkg-config file asks for zlib; Android has zlib built in, so give it a stub.
cat > "$PFX/lib/pkgconfig/zlib.pc" <<'PC'
Name: zlib
Description: zlib (Android system library)
Version: 1.2.13
Libs: -lz
Cflags:
PC

cmake_android() { # source-dir, extra cmake args...
  local src="$1"; shift
  cmake -S "$src" -B "$src/build-android" \
    -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_INSTALL_PREFIX="$PFX" "$@"
  cmake --build "$src/build-android" -j "$JOBS"
  cmake --install "$src/build-android"
}

build_gd_libs() {
  echo "== libjpeg-turbo $JPEG_VER"
  fetch jpeg.tgz "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/${JPEG_VER}/libjpeg-turbo-${JPEG_VER}.tar.gz" \
                 "https://github.com/libjpeg-turbo/libjpeg-turbo/archive/refs/tags/${JPEG_VER}.tar.gz"
  rm -rf src/jpeg && mkdir -p src/jpeg && tar xzf jpeg.tgz -C src/jpeg --strip-components=1
  cmake_android "$ROOT/src/jpeg" -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DWITH_TURBOJPEG=OFF

  echo "== libpng $PNG_VER"
  fetch png.tgz "https://github.com/pnggroup/libpng/archive/refs/tags/v${PNG_VER}.tar.gz" \
                "https://github.com/glennrp/libpng/archive/refs/tags/v${PNG_VER}.tar.gz"
  rm -rf src/png && mkdir -p src/png && tar xzf png.tgz -C src/png --strip-components=1
  cmake_android "$ROOT/src/png" -DPNG_SHARED=OFF -DPNG_STATIC=ON -DPNG_TESTS=OFF -DPNG_TOOLS=OFF
}

# php.net only keeps the newest tarballs, so an older pinned version can disappear.
# Try the pinned one, then the museum, then the newest release of the same 8.3 line.
download_php() {
  [ -s php.txz ] && return 0
  if fetch php.txz "https://www.php.net/distributions/php-${PHP_VER}.tar.xz" \
                   "https://museum.php.net/php8/php-${PHP_VER}.tar.xz"; then
    return 0
  fi
  echo "pinned PHP $PHP_VER not available, looking up the newest 8.3 release"
  local latest
  latest="$(curl -fsSL 'https://www.php.net/releases/index.php?json&version=8.3' \
            | python3 -c 'import sys,json; print(json.load(sys.stdin)["version"])')" || return 1
  echo "using PHP $latest"
  fetch php.txz "https://www.php.net/distributions/php-${latest}.tar.xz"
}

build_php() { # 1 = with GD, 0 = without
  local with_gd="$1"
  if [ ! -d src/php ]; then
    echo "== PHP (download)"
    download_php || return 1
    mkdir -p src/php && tar xJf php.txz -C src/php --strip-components=1
  fi
  cd "$ROOT/src/php"
  make distclean >/dev/null 2>&1 || true

  local libdir="$PFX/lib"
  [ -d "$PFX/lib64" ] && libdir="$PFX/lib64"
  local args=(--host="$TRIPLE" --build=x86_64-linux-gnu --prefix="$PFX/php"
              --disable-all --enable-cli --disable-cgi --disable-phpdbg
              --without-pear --without-pcre-jit)
  if [ "$with_gd" = "1" ]; then
    args+=(--enable-gd --with-jpeg)
    export JPEG_CFLAGS="-I$PFX/include" JPEG_LIBS="-L$libdir -ljpeg"
    export PNG_CFLAGS="-I$PFX/include" PNG_LIBS="-L$libdir -lpng16 -lz -lm"
  fi

  # configure cannot run test programs while cross compiling, so answer the
  # questions that cannot be tested (Android's libc is "bionic").
  export ac_cv_func_getaddrinfo=yes
  export ac_cv_func_res_nsearch=no ac_cv_func_res_search=no ac_cv_func_dn_skipname=no
  export ac_cv_func_dn_expand=no ac_cv_func_res_ninit=no
  export php_cv_have_crypt_r=no

  echo "== PHP configure (gd=$with_gd)"
  if ! CFLAGS="-O2 -fPIE -I$PFX/include" LDFLAGS="-pie -L$libdir" LIBS="-lm" \
       ./configure "${args[@]}"; then
    echo "---- last lines of config.log ----"
    tail -n 80 config.log || true
    cd "$ROOT"; return 1
  fi

  echo "== PHP make"
  if ! make -j "$JOBS" sapi/cli/php; then
    echo "PHP make failed (retrying once without parallel jobs to show the real error)"
    make sapi/cli/php 2>&1 | tail -n 60 || true
    cd "$ROOT"; return 1
  fi
  "$STRIP" -o "$OUT/libphp_cli.so" sapi/cli/php
  cd "$ROOT"
}

if build_gd_libs && build_php 1; then
  echo "PHP runtime built WITH GD"
elif build_php 0; then
  echo "PHP runtime built WITHOUT GD (photos will be copied, not resized)"
else
  echo "PHP runtime build failed"; exit 1
fi

"$TC/bin/llvm-readelf" -h "$OUT/libphp_cli.so" | grep -E "Class|Machine" || true
ls -l "$OUT/libphp_cli.so"
