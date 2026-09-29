#!/usr/bin/env bash
# Build BodySlide.exe / OutfitStudio.exe with the repo's documented CMake build
# and stage the FOMOD payload (tools/fomod-stage.sh). Runs on the shared
# modforge pipeline's Windows runner.
#
# This mirrors .github/workflows/cmake-release.yml's Windows job's build steps
# (same generator, same vcpkg dependencies, same configure options) with two
# deliberate differences:
#   * BSOS_BUILD_TESTS=OFF and the BSOSTests target is not built: on this
#     branch the tests target does not compile on GitHub runners (its includes
#     do not reach the vendored lib/TinyXML-2, so every tests TU fails with
#     `tinyxml2.h: No such file or directory` - see the failed "CMake
#     RelWithDebInfo" runs), and the tests are upstream CI's job, not this
#     packaging layer's;
#   * the package step is tools/fomod-stage.sh (the FOMOD payload layout),
#     not a zip of the whole output directory.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${RUNNER_TEMP:?tools/fomod-build.sh runs on a GitHub Windows runner}"

VCPKG_ROOT="${VCPKG_ROOT:-$RUNNER_TEMP/vcpkg}"
export VCPKG_DEFAULT_BINARY_CACHE="$PWD/vcpkg-binary-cache"
mkdir -p "$VCPKG_DEFAULT_BINARY_CACHE"

if [ ! -x "$VCPKG_ROOT/vcpkg.exe" ]; then
  git clone --depth 1 https://github.com/microsoft/vcpkg.git "$VCPKG_ROOT"
  ( cd "$VCPKG_ROOT" && cmd.exe //c bootstrap-vcpkg.bat -disableMetrics )
fi

triplet=x64-windows-static
"$VCPKG_ROOT/vcpkg.exe" install \
  "wxwidgets[debug-support]:$triplet" \
  "catch2:$triplet" \
  "bullet3:$triplet" \
  "openexr:$triplet"

cmake -S . -B build/fomod \
  -G "Visual Studio 18 2026" \
  -A x64 \
  -DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" \
  "-DCMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO=RelWithDebInfo;Release;None;NOCONFIG" \
  -DVCPKG_TARGET_TRIPLET="$triplet" \
  -DBSOS_BUILD_TESTS=OFF \
  -DBSOS_ENABLE_FBXSDK=OFF

cmake --build build/fomod --config RelWithDebInfo --target BodySlide OutfitStudio --parallel

tools/fomod-stage.sh
