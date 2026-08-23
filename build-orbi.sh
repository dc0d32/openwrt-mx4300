#!/usr/bin/env bash
# Build one RBR20 image and one shared RBS20 image for AP-5 through AP-7.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=orbi-versions.env
# shellcheck disable=SC1091
source "$ROOT/orbi-versions.env"

OPENWRT_DIR="${1:-$ROOT/orbi-openwrt}"
MODE="${2:-build}"
JOBS="${OPENWRT_JOBS:-$(nproc)}"

if [ ! -x "$OPENWRT_DIR/scripts/feeds" ]; then
  echo "Orbi OpenWrt source not prepared at $OPENWRT_DIR" >&2
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
CONFIG_TARGET_ipq40xx=y
CONFIG_TARGET_ipq40xx_generic=y
CONFIG_TARGET_MULTI_PROFILE=y
CONFIG_TARGET_DEVICE_ipq40xx_generic_DEVICE_netgear_rbr20=y
CONFIG_TARGET_DEVICE_ipq40xx_generic_DEVICE_netgear_rbs20=y
CONFIG_DEVEL=y
CONFIG_CCACHE=y
CONFIG_PACKAGE_apk-mbedtls=y
CONFIG_PACKAGE_ath10k-firmware-qca4019=y
CONFIG_PACKAGE_ath10k-firmware-qca4019-ct=n
CONFIG_PACKAGE_ath10k-firmware-qca9888=y
CONFIG_PACKAGE_ath10k-firmware-qca9888-ct=n
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
    { echo "required Orbi config missing: CONFIG_$1=y" >&2; exit 1; }
}
reject_y() {
  if grep -qx "CONFIG_$1=y" .config; then
    echo "forbidden Orbi config enabled: CONFIG_$1=y" >&2
    exit 1
  fi
}

require_y TARGET_MULTI_PROFILE
require_y TARGET_DEVICE_ipq40xx_generic_DEVICE_netgear_rbr20
require_y TARGET_DEVICE_ipq40xx_generic_DEVICE_netgear_rbs20
require_y PACKAGE_ath10k-firmware-qca4019
require_y PACKAGE_ath10k-firmware-qca9888
require_y PACKAGE_kmod-ath10k
require_y PACKAGE_kmod-batman-adv
require_y PACKAGE_libustream-mbedtls
require_y PACKAGE_wpad-mesh-mbedtls
require_y PACKAGE_luci
require_y PACKAGE_iperf3
require_y CCACHE
reject_y PACKAGE_ath10k-firmware-qca4019-ct
reject_y PACKAGE_ath10k-firmware-qca9888-ct
reject_y PACKAGE_dawn
reject_y PACKAGE_kmod-ath10k-ct
reject_y PACKAGE_luci-app-dawn
cmp "$ROOT/files/etc/dropbear/authorized_keys" \
  "$OPENWRT_DIR/files/etc/dropbear/authorized_keys"

if [ "$MODE" = configure-only ]; then
  echo "Orbi configuration validated."
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

target_dir="$OPENWRT_DIR/bin/targets/$ORBI_TARGET"
shopt -s nullglob
images=()
manifests=("$target_dir"/*.manifest)
[ "${#manifests[@]}" -eq 1 ] ||
  { echo "expected one shared Orbi manifest, found ${#manifests[@]}" >&2; exit 1; }
manifest="${manifests[0]}"
test -s "$manifest"
for profile in netgear_rbr20 netgear_rbs20; do
  factory=("$target_dir"/*"$profile"*squashfs-factory.img)
  sysupgrade=("$target_dir"/*"$profile"*squashfs-sysupgrade.bin)
  [ "${#factory[@]}" -eq 1 ] ||
    { echo "expected one $profile factory image, found ${#factory[@]}" >&2; exit 1; }
  [ "${#sysupgrade[@]}" -eq 1 ] ||
    { echo "expected one $profile sysupgrade image, found ${#sysupgrade[@]}" >&2; exit 1; }
  test -s "${factory[0]}"
  test -s "${sysupgrade[0]}"
  images+=("${factory[0]}" "${sysupgrade[0]}")
done

rootfs="$(find "$OPENWRT_DIR/build_dir" -path '*/root-ipq40xx/etc/dropbear/authorized_keys' -print -quit)"
test -n "$rootfs"
cmp "$ROOT/files/etc/dropbear/authorized_keys" "$rootfs"
for manifest in "${manifests[@]}"; do
  grep -Eq '^ath10k-firmware-qca4019([[:space:]-])' "$manifest"
  grep -Eq '^ath10k-firmware-qca9888([[:space:]-])' "$manifest"
  grep -Eq '^kmod-ath10k([[:space:]-])' "$manifest"
  grep -Eq '^kmod-batman-adv([[:space:]-])' "$manifest"
  grep -Eq '^wpad-mesh-mbedtls([[:space:]-])' "$manifest"
  if grep -Eq '^(dawn|kmod-ath10k-ct|luci-app-dawn|wpad-basic-mbedtls)([[:space:]-])' "$manifest"; then
    echo "forbidden package present in Orbi image: $manifest" >&2
    exit 1
  fi
done

cp "$ROOT/orbi-versions.env" "$target_dir/source-versions.txt"
cp "$ROOT/orbi-feeds.conf.lock" "$target_dir/feeds.lock"
{
  echo "source_repository=$ORBI_REPOSITORY"
  echo "source_commit=$ORBI_COMMIT"
  echo "profiles=netgear_rbr20,netgear_rbs20"
} > "$target_dir/wrapper-provenance.txt"
"$ROOT/record-provenance.sh" "$target_dir" "$target_dir/wrapper-provenance.txt"

sha256sum "${images[@]}"
