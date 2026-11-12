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
# The GitHub workflow runs this with "continue-on-error", so the APK still builds if
# this script fails; the app then uses the C++ fallback for photos and videos.
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

export CC="$TC/bin/${TRIPLE}${API}-clang"
export CXX="$TC/bin/${TRIPLE}${API}-clang++"
export AR="$TC/bin/llvm-ar"
export RANLIB="$TC/bin/llvm-ranlib"
export STRIP="$TC/bin/llvm-strip"
export NM="$TC/bin/llvm-nm"

fetch() { [ -f "$2" ] || curl -fsSL --retry 3 "$1" -o "$2"; }

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
  fetch "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/${JPEG_VER}/libjpeg-turbo-${JPEG_VER}.tar.gz" jpeg.tgz
  rm -rf src/jpeg && mkdir -p src/jpeg && tar xzf jpeg.tgz -C src/jpeg --strip-components=1
  cmake_android "$ROOT/src/jpeg" -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DWITH_TURBOJPEG=OFF

  echo "== libpng $PNG_VER"
  fetch "https://github.com/pnggroup/libpng/archive/refs/tags/v${PNG_VER}.tar.gz" png.tgz
  rm -rf src/png && mkdir -p src/png && tar xzf png.tgz -C src/png --strip-components=1
  cmake_android "$ROOT/src/png" -DPNG_SHARED=OFF -DPNG_STATIC=ON -DPNG_TESTS=OFF -DPNG_TOOLS=OFF
}

build_php() { # 1 = with GD, 0 = without
  local with_gd="$1"
  if [ ! -d src/php ]; then
    echo "== PHP $PHP_VER (download)"
    fetch "https://www.php.net/distributions/php-${PHP_VER}.tar.xz" php.txz
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

  echo "== PHP configure (gd=$with_gd)"
  CFLAGS="-O2 -fPIE -I$PFX/include" LDFLAGS="-pie -L$libdir" LIBS="-lm" \
    ./configure "${args[@]}" || { tail -n 60 config.log || true; cd "$ROOT"; return 1; }

  echo "== PHP make"
  make -j "$JOBS" sapi/cli/php || { cd "$ROOT"; return 1; }
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


