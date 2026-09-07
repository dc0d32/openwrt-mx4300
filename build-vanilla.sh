#!/usr/bin/env bash
# Build the upstream, non-NSS MX4300 comparison image.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=vanilla-versions.env
# shellcheck disable=SC1091
source "$ROOT/vanilla-versions.env"

OPENWRT_DIR="${1:-$ROOT/vanilla-openwrt}"
MODE="${2:-build}"
JOBS="${OPENWRT_JOBS:-$(nproc)}"

if [ ! -x "$OPENWRT_DIR/scripts/feeds" ]; then
  echo "Vanilla OpenWrt source not prepared at $OPENWRT_DIR" >&2
  exit 2
fi

cd "$OPENWRT_DIR"
./scripts/feeds update -a
./scripts/feeds install -a

cat > .config <<'EOF'
CONFIG_TARGET_qualcommax=y
CONFIG_TARGET_qualcommax_ipq807x=y
CONFIG_TARGET_qualcommax_ipq807x_DEVICE_linksys_mx4300=y
CONFIG_DEVEL=y
CONFIG_CCACHE=y

# Universal router/AP image. Runtime roles remain declarative UCI.
CONFIG_PACKAGE_acme-acmesh=y
CONFIG_PACKAGE_adguardhome=y
CONFIG_PACKAGE_batctl-full=y
CONFIG_PACKAGE_collectd=y
CONFIG_PACKAGE_collectd-mod-cpu=y
CONFIG_PACKAGE_collectd-mod-interface=y
CONFIG_PACKAGE_collectd-mod-iwinfo=y
CONFIG_PACKAGE_collectd-mod-load=y
CONFIG_PACKAGE_collectd-mod-memory=y
CONFIG_PACKAGE_collectd-mod-network=y
CONFIG_PACKAGE_collectd-mod-rrdtool=y
CONFIG_PACKAGE_crowdsec-firewall-bouncer=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_ethtool=y
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_iperf3=y
CONFIG_PACKAGE_iw=y
CONFIG_PACKAGE_jq=y
CONFIG_PACKAGE_kmod-batman-adv=y
CONFIG_PACKAGE_kmod-gre=y
CONFIG_PACKAGE_kmod-ifb=y
CONFIG_PACKAGE_kmod-lib-lz4=y
CONFIG_PACKAGE_kmod-lib-zstd=y
CONFIG_PACKAGE_kmod-sched-cake=y
CONFIG_PACKAGE_kmod-wireguard=y
CONFIG_PACKAGE_lldpd=y
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-app-acme=y
CONFIG_PACKAGE_luci-app-attendedsysupgrade=y
CONFIG_PACKAGE_luci-app-crowdsec-firewall-bouncer=y
CONFIG_PACKAGE_luci-app-mesh-topology=y
CONFIG_PACKAGE_luci-app-nlbwmon=y
CONFIG_PACKAGE_luci-app-package-manager=y
CONFIG_PACKAGE_luci-app-sqm=y
CONFIG_PACKAGE_luci-app-statistics=y
CONFIG_PACKAGE_luci-app-unbound=y
CONFIG_PACKAGE_luci-app-watchcat=y
CONFIG_PACKAGE_luci-app-wol=y
CONFIG_PACKAGE_luci-mod-dashboard=y
CONFIG_PACKAGE_luci-proto-batman-adv=y
CONFIG_PACKAGE_luci-proto-wireguard=y
CONFIG_PACKAGE_luci-ssl-openssl=y
CONFIG_PACKAGE_nlbwmon=y
CONFIG_PACKAGE_qrencode=y
CONFIG_PACKAGE_rsync=y
CONFIG_PACKAGE_socat=y
CONFIG_PACKAGE_sqm-scripts=y
CONFIG_PACKAGE_tcpdump=y
CONFIG_PACKAGE_tmux=y
CONFIG_PACKAGE_umdns=y
CONFIG_PACKAGE_unbound-control=y
CONFIG_PACKAGE_watchcat=y
CONFIG_PACKAGE_wireguard-tools=y
CONFIG_PACKAGE_wpad-basic-mbedtls=n
CONFIG_PACKAGE_wpad-mesh-openssl=y
CONFIG_PACKAGE_zram-swap=y

# Keep one implementation for each overlapping facility.
CONFIG_PACKAGE_avahi-dbus-daemon=n
CONFIG_PACKAGE_dawn=n
CONFIG_PACKAGE_luci-app-dawn=n
CONFIG_PACKAGE_luci-app-vnstat2=n
CONFIG_PACKAGE_vnstat2=n
CONFIG_PACKAGE_vnstati2=n
EOF

make defconfig V=s

require_y() {
  grep -qx "CONFIG_$1=y" .config ||
    { echo "required vanilla config missing: CONFIG_$1=y" >&2; exit 1; }
}
reject_y() {
  if grep -qx "CONFIG_$1=y" .config; then
    echo "forbidden vanilla config enabled: CONFIG_$1=y" >&2
    exit 1
  fi
}

require_y TARGET_qualcommax_ipq807x_DEVICE_linksys_mx4300
require_y PACKAGE_kmod-ath11k-ahb
require_y PACKAGE_kmod-batman-adv
require_y PACKAGE_lldpd
require_y PACKAGE_luci-app-mesh-topology
require_y PACKAGE_umdns
require_y PACKAGE_wpad-mesh-openssl
require_y CCACHE
reject_y PACKAGE_avahi-dbus-daemon
reject_y PACKAGE_dawn
reject_y PACKAGE_kmod-qca-nss-drv
reject_y PACKAGE_kmod-qca-nss-drv-wifi-meshmgr
reject_y PACKAGE_kmod-qca-nss-ecm
reject_y PACKAGE_luci-app-dawn
reject_y PACKAGE_nss-firmware
reject_y PACKAGE_sqm-scripts-nss
reject_y PACKAGE_vnstat2
cmp "$ROOT/files/etc/dropbear/authorized_keys" \
  "$OPENWRT_DIR/files/etc/dropbear/authorized_keys" ||
  { echo "factory-reset deploy key is not staged" >&2; exit 1; }

if [ "$MODE" = configure-only ]; then
  echo "Vanilla MX4300 configuration validated."
  exit 0
fi
if [ "$MODE" != build ]; then
  echo "unknown mode: $MODE (expected build or configure-only)" >&2
  exit 2
fi

make download -j"$JOBS" V=s
make -j"$JOBS" V=s

target_dir="$OPENWRT_DIR/bin/targets/$VANILLA_TARGET"
shopt -s nullglob
factory=("$target_dir"/*linksys_mx4300*squashfs-factory.bin)
sysupgrade=("$target_dir"/*linksys_mx4300*squashfs-sysupgrade.bin)
manifests=("$target_dir"/*linksys_mx4300.manifest)
[ "${#factory[@]}" -eq 1 ] ||
  { echo "expected one vanilla MX4300 factory image, found ${#factory[@]}" >&2; exit 1; }
[ "${#sysupgrade[@]}" -eq 1 ] ||
  { echo "expected one vanilla MX4300 sysupgrade image, found ${#sysupgrade[@]}" >&2; exit 1; }
[ "${#manifests[@]}" -eq 1 ] ||
  { echo "expected one vanilla MX4300 manifest, found ${#manifests[@]}" >&2; exit 1; }
manifest="${manifests[0]}"
test -s "${factory[0]}"
test -s "${sysupgrade[0]}"
test -s "$manifest"

rootfs="$(find "$OPENWRT_DIR/build_dir" -path '*/root-qualcommax/etc/dropbear/authorized_keys' -print -quit)"
test -n "$rootfs"
cmp "$ROOT/files/etc/dropbear/authorized_keys" "$rootfs"
grep -Eq '^kmod-ath11k-ahb([[:space:]-])' "$manifest"
grep -Eq '^kmod-batman-adv([[:space:]-])' "$manifest"
grep -Eq '^lldpd([[:space:]-])' "$manifest"
grep -Eq '^luci-app-mesh-topology([[:space:]-])' "$manifest"
grep -Eq '^wpad-mesh-openssl([[:space:]-])' "$manifest"
if grep -Eq '^(kmod-qca-nss-drv|kmod-qca-nss-ecm|nss-firmware|sqm-scripts-nss)([[:space:]-])' "$manifest"; then
  echo "forbidden NSS offload package present in vanilla image" >&2
  exit 1
fi

cp "$ROOT/vanilla-versions.env" "$target_dir/source-versions.txt"
cp "$ROOT/vanilla-feeds.conf.lock" "$target_dir/feeds.lock"
{
  echo "source_repository=$VANILLA_REPOSITORY"
  echo "source_commit=$(git rev-parse HEAD)"
  echo "profile=$VANILLA_PROFILE"
  echo "nss_offload=0"
  echo "source_patches=none"
} > "$target_dir/wrapper-provenance.txt"
"$ROOT/record-provenance.sh" "$target_dir" "$target_dir/wrapper-provenance.txt"

sha256sum "${factory[0]}" "${sysupgrade[0]}"
