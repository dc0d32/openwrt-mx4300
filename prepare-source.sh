#!/usr/bin/env bash
# Materialize the immutable qosmio source tree used by CI and local builds.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=versions.env
# shellcheck disable=SC1091
source "$ROOT/versions.env"
OPENWRT_DIR="${1:-$ROOT/openwrt}"
new_checkout=false

if [ ! -d "$OPENWRT_DIR/.git" ]; then
  [ ! -e "$OPENWRT_DIR" ] ||
    { echo "$OPENWRT_DIR exists but is not a git checkout" >&2; exit 2; }
  git clone --filter=blob:none --no-checkout "$OPENWRT_REPOSITORY" "$OPENWRT_DIR"
  new_checkout=true
fi

actual_origin="$(git -C "$OPENWRT_DIR" remote get-url origin)"
[ "$actual_origin" = "$OPENWRT_REPOSITORY" ] ||
  { echo "unexpected origin: $actual_origin" >&2; exit 2; }

if ! $new_checkout &&
  [ -n "$(git -C "$OPENWRT_DIR" status --porcelain --untracked-files=no)" ]; then
  echo "tracked changes in $OPENWRT_DIR; refusing to overwrite them" >&2
  exit 2
fi

git -C "$OPENWRT_DIR" fetch --depth=1 origin "$OPENWRT_COMMIT"
git -C "$OPENWRT_DIR" checkout --detach "$OPENWRT_COMMIT"
cp "$ROOT/feeds.conf.lock" "$OPENWRT_DIR/feeds.conf"
rm -f "$OPENWRT_DIR/tools/lzma/patches/102-format-security.patch"
cp "$ROOT/patches/102-lzma-modern-compiler.patch" \
  "$OPENWRT_DIR/tools/lzma/patches/102-modern-compiler.patch"
install -D -m 0600 "$ROOT/files/etc/dropbear/authorized_keys" \
  "$OPENWRT_DIR/files/etc/dropbear/authorized_keys"

echo "Prepared qosmio/openwrt-ipq@$OPENWRT_COMMIT in $OPENWRT_DIR"
