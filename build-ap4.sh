#!/usr/bin/env bash
# Build AP-4's official ath79 source with the immutable recovery key.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ap4-versions.env
# shellcheck disable=SC1091
source "$ROOT/ap4-versions.env"

OPENWRT_DIR="${1:-$ROOT/ap4-openwrt}"
MODE="${2:-build}"
JOBS="${OPENWRT_JOBS:-$(nproc)}"

if [ ! -x "$OPENWRT_DIR/scripts/feeds" ]; then
  echo "AP-4 OpenWrt source not prepared at $OPENWRT_DIR" >&2
  exit 2
fi

cd "$OPENWRT_DIR"
./scripts/feeds update -a
./scripts/feeds install -a
install -D -m 0644 "$ROOT/patches/104-util-linux-env-bash.patch" \
  package/utils/util-linux/patches/999-nixos-env-bash.patch

# This host tool embeds the build machine's dynamic loader. Persistent caches
# may have been populated on another NixOS host, so always rebuild it locally.
rm -f scripts/config/conf
cat > .config <<'EOF'
CONFIG_TARGET_ath79=y
CONFIG_TARGET_ath79_generic=y
CONFIG_TARGET_ath79_generic_DEVICE_tplink_archer-c7-v2=y
CONFIG_DEVEL=y
CONFIG_CCACHE=y
CONFIG_PACKAGE_apk-mbedtls=y
CONFIG_PACKAGE_ath10k-firmware-qca988x=y
CONFIG_PACKAGE_ath10k-firmware-qca988x-ct=n
CONFIG_PACKAGE_batctl-default=y
CONFIG_PACKAGE_iperf3=y
CONFIG_PACKAGE_kmod-ath10k=y
CONFIG_PACKAGE_kmod-ath10k-ct=n
CONFIG_PACKAGE_kmod-batman-adv=y
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-app-attendedsysupgrade=y
CONFIG_PACKAGE_luci-app-package-manager=y
CONFIG_PACKAGE_luci-mod-dashboard=y
CONFIG_PACKAGE_luci-proto-batman-adv=y
CONFIG_PACKAGE_libustream-mbedtls=y
CONFIG_PACKAGE_umdns=y
CONFIG_PACKAGE_wpad-basic-mbedtls=n
CONFIG_PACKAGE_wpad-mesh-mbedtls=y
CONFIG_PACKAGE_dawn=n
CONFIG_PACKAGE_luci-app-dawn=n
EOF

make defconfig

require_y() {
  grep -qx "CONFIG_$1=y" .config ||
    { echo "required AP-4 config missing: CONFIG_$1=y" >&2; exit 1; }
}
reject_y() {
  if grep -qx "CONFIG_$1=y" .config; then
    echo "forbidden AP-4 config enabled: CONFIG_$1=y" >&2
    exit 1
  fi
}

require_y TARGET_ath79_generic_DEVICE_tplink_archer-c7-v2
require_y PACKAGE_apk-mbedtls
require_y PACKAGE_ath10k-firmware-qca988x
require_y PACKAGE_kmod-ath10k
require_y PACKAGE_kmod-batman-adv
require_y PACKAGE_libustream-mbedtls
require_y PACKAGE_wpad-mesh-mbedtls
require_y PACKAGE_luci
require_y PACKAGE_iperf3
require_y CCACHE
reject_y PACKAGE_dawn
reject_y PACKAGE_ath10k-firmware-qca988x-ct
reject_y PACKAGE_kmod-ath10k-ct
reject_y PACKAGE_luci-app-dawn
cmp "$ROOT/files/etc/dropbear/authorized_keys" \
  "$OPENWRT_DIR/files/etc/dropbear/authorized_keys"

if [ "$MODE" = configure-only ]; then
  echo "AP-4 configuration validated."
  exit 0
fi
if [ "$MODE" != build ]; then
  echo "unknown mode: $MODE (expected build or configure-only)" >&2
  exit 2
fi

rm -rf build_dir/target-*/apk-* build_dir/target-*/openssl-* \
  build_dir/target-*/util-linux-*
make download -j"$JOBS" V=s
make -j"$JOBS" V=s

target_dir="$OPENWRT_DIR/bin/targets/$AP4_TARGET"
shopt -s nullglob
images=("$target_dir"/*tplink_archer-c7-v2*squashfs-sysupgrade.bin)
manifests=("$target_dir"/*tplink_archer-c7-v2.manifest)
[ "${#images[@]}" -eq 1 ] ||
  { echo "expected one AP-4 sysupgrade image, found ${#images[@]}" >&2; exit 1; }
[ "${#manifests[@]}" -eq 1 ] ||
  { echo "expected one AP-4 manifest, found ${#manifests[@]}" >&2; exit 1; }
image="${images[0]}"
manifest="${manifests[0]}"
test -s "$image"
test -s "$manifest"

rootfs="$(find "$OPENWRT_DIR/build_dir" -path '*/root-ath79/etc/dropbear/authorized_keys' -print -quit)"
test -n "$rootfs"
cmp "$ROOT/files/etc/dropbear/authorized_keys" "$rootfs"
grep -Eq '^kmod-batman-adv([[:space:]-])' "$manifest"
grep -Eq '^wpad-mesh-mbedtls([[:space:]-])' "$manifest"
if grep -Eq '^(dawn|luci-app-dawn)([[:space:]-])' "$manifest"; then
  echo "forbidden DAWN package present in AP-4 image" >&2
  exit 1
fi

cp "$ROOT/ap4-versions.env" "$target_dir/source-versions.txt"
cp "$ROOT/ap4-feeds.conf.lock" "$target_dir/feeds.lock"
{
  echo "source_repository=$AP4_REPOSITORY"
  echo "source_commit=$AP4_COMMIT"
  echo "profile=$AP4_PROFILE"
} > "$target_dir/wrapper-provenance.txt"
"$ROOT/record-provenance.sh" "$target_dir" "$target_dir/wrapper-provenance.txt"

sha256sum "$image"
