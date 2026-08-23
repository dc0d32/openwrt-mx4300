#!/usr/bin/env bash
# Materialize the exact official OpenWrt source and feeds used by the Orbis.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=orbi-versions.env
# shellcheck disable=SC1091
source "$ROOT/orbi-versions.env"
OPENWRT_DIR="${1:-$ROOT/orbi-openwrt}"
new_checkout=false

if [ ! -d "$OPENWRT_DIR/.git" ]; then
  [ ! -e "$OPENWRT_DIR" ] ||
    { echo "$OPENWRT_DIR exists but is not a git checkout" >&2; exit 2; }
  git clone --filter=blob:none --no-checkout "$ORBI_REPOSITORY" "$OPENWRT_DIR"
  new_checkout=true
fi

actual_origin="$(git -C "$OPENWRT_DIR" remote get-url origin)"
[ "$actual_origin" = "$ORBI_REPOSITORY" ] ||
  { echo "unexpected origin: $actual_origin" >&2; exit 2; }

if ! $new_checkout &&
  [ -n "$(git -C "$OPENWRT_DIR" status --porcelain --untracked-files=no)" ]; then
  echo "tracked changes in $OPENWRT_DIR; refusing to overwrite them" >&2
  exit 2
fi

git -C "$OPENWRT_DIR" fetch --depth=1 origin "$ORBI_COMMIT"
git -C "$OPENWRT_DIR" checkout --detach "$ORBI_COMMIT"
cp "$ROOT/orbi-feeds.conf.lock" "$OPENWRT_DIR/feeds.conf"
install -D -m 0600 "$ROOT/files/etc/dropbear/authorized_keys" \
  "$OPENWRT_DIR/files/etc/dropbear/authorized_keys"

echo "Prepared openwrt/openwrt@$ORBI_COMMIT in $OPENWRT_DIR"
