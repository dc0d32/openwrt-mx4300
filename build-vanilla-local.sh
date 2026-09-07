#!/usr/bin/env bash
# Build upstream OpenWrt in its supported Debian host environment on Andromeda.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CACHE_ROOT="${OPENWRT_CACHE_ROOT:-${XDG_CACHE_HOME:-$HOME/.cache}/openwrt-mx4300}"
MODE="${1:-build}"
BUILD_UID="$(stat -c '%u' "$ROOT")"
BUILD_GID="$(stat -c '%g' "$ROOT")"

mkdir -p "$CACHE_ROOT"

exec docker run --rm \
  --env BUILD_GID="$BUILD_GID" \
  --env BUILD_UID="$BUILD_UID" \
  --env MODE="$MODE" \
  --env OPENWRT_JOBS="${OPENWRT_JOBS:-$(nproc)}" \
  --volume "$ROOT:/wrapper:ro" \
  --volume "$CACHE_ROOT:/work" \
  debian:bookworm-slim \
  bash -lc '
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y --no-install-recommends \
      build-essential ca-certificates clang flex bison g++ gawk gcc-multilib \
      g++-multilib gettext git libncurses-dev libssl-dev python3 \
      python3-setuptools rsync swig unzip zlib1g-dev file wget subversion \
      libelf-dev patch perl-modules perl python3-dev intltool \
      libxml-parser-perl xsltproc mercurial quilt
    getent group "$BUILD_GID" >/dev/null || groupadd --gid "$BUILD_GID" builder
    useradd --create-home --uid "$BUILD_UID" --gid "$BUILD_GID" builder
    chown -R "$BUILD_UID:$BUILD_GID" /work
    exec runuser -u builder -- env \
      HOME=/home/builder OPENWRT_JOBS="$OPENWRT_JOBS" \
      bash -lc "/wrapper/prepare-vanilla-source.sh /work/vanilla-source && /wrapper/build-vanilla.sh /work/vanilla-source '$MODE'"
  '
