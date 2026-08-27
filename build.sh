#!/usr/bin/env bash
# Configure and build the one firmware image shared by every MX4300 role.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
OPENWRT_DIR="${1:-$ROOT/openwrt}"
MODE="${2:-build}"
JOBS="${OPENWRT_JOBS:-$(nproc)}"

if [ ! -x "$OPENWRT_DIR/scripts/feeds" ]; then
  echo "OpenWrt source not prepared at $OPENWRT_DIR" >&2
  echo "Run $ROOT/prepare-source.sh first." >&2
  exit 2
fi

cd "$OPENWRT_DIR"
./scripts/feeds update -a
./scripts/feeds install -a
install -D -m 0644 "$ROOT/patches/104-util-linux-env-bash.patch" \
  package/utils/util-linux/patches/999-nixos-env-bash.patch
go_values=feeds/packages/lang/golang/golang-values.mk
if grep -q '^  GO_LDSO \\$' "$go_values"; then
  patch -p1 < "$ROOT/patches/103-golang-preserve-go-ldso.patch"
fi
# This host tool embeds the build machine's dynamic loader. Persistent caches
# may have been populated on another NixOS host, so always rebuild it locally.
rm -f scripts/config/conf
cp nss-setup/config-nss.seed .config

cat >> .config <<'EOF'
CONFIG_TARGET_qualcommax_ipq807x_DEVICE_linksys_mx4300=y

# One universal image: router/AP behavior is selected by declarative UCI and
# service policy after installation, not by building role-specific firmware.
CONFIG_PACKAGE_luci-proto-batman-adv=y
CONFIG_PACKAGE_batctl-full=y
CONFIG_PACKAGE_adguardhome=y
CONFIG_PACKAGE_luci-app-unbound=y
CONFIG_PACKAGE_unbound-control=y
CONFIG_PACKAGE_iperf3=y
CONFIG_PACKAGE_tmux=y
CONFIG_PACKAGE_luci-app-wol=y
CONFIG_PACKAGE_luci-app-crowdsec-firewall-bouncer=y
CONFIG_PACKAGE_qrencode=y
CONFIG_PACKAGE_luci-mod-dashboard=y
CONFIG_PACKAGE_luci-app-mesh-topology=y
CONFIG_PACKAGE_zram-swap=y
CONFIG_PACKAGE_kmod-lib-lz4=y
CONFIG_PACKAGE_kmod-lib-zstd=y

# Preserve NSS mesh and multicast support. The mesh manager transitively selects
# NSS Wi-Fi offload; they cannot be separated in this tree. This is safe for the
# current model because it uses VLAN subinterfaces plus one bridge per VLAN,
# never the incompatible DSA bridge-VLAN filtering feature.
CONFIG_NSS_DRV_CRYPTO_ENABLE=y
CONFIG_PACKAGE_kmod-qca-nss-crypto=y
CONFIG_NSS_DRV_IGS_ENABLE=y
CONFIG_PACKAGE_kmod-qca-nss-drv-igs=y
CONFIG_NSS_DRV_WIFI_MESH_ENABLE=y
CONFIG_PACKAGE_kmod-qca-nss-drv-wifi-meshmgr=y

# Remove unused or overlapping packages. umdns remains the sole mDNS daemon;
# collectd + nlbwmon remain the router's telemetry path.
CONFIG_PACKAGE_avahi-dbus-daemon=n
CONFIG_PACKAGE_luci-app-dawn=n
CONFIG_PACKAGE_dawn=n
CONFIG_PACKAGE_luci-app-vnstat2=n
CONFIG_PACKAGE_vnstat2=n
CONFIG_PACKAGE_vnstati2=n
EOF

make defconfig V=s

require_y() {
  grep -qx "CONFIG_$1=y" .config ||
    { echo "required config missing: CONFIG_$1=y" >&2; exit 1; }
}
reject_y() {
  if grep -qx "CONFIG_$1=y" .config; then
    echo "forbidden config enabled: CONFIG_$1=y" >&2
    exit 1
  fi
}

require_y TARGET_qualcommax_ipq807x_DEVICE_linksys_mx4300
require_y ATH11K_NSS_MESH_SUPPORT
require_y PACKAGE_kmod-batman-adv
require_y PACKAGE_kmod-qca-nss-drv-wifi-meshmgr
require_y PACKAGE_lldpd
require_y PACKAGE_luci-app-mesh-topology
require_y NSS_DRV_WIFIOFFLOAD_ENABLE
require_y CCACHE
reject_y PACKAGE_avahi-dbus-daemon
reject_y PACKAGE_dawn
reject_y PACKAGE_vnstat2
cmp "$ROOT/files/etc/dropbear/authorized_keys" \
  "$OPENWRT_DIR/files/etc/dropbear/authorized_keys" ||
  { echo "factory-reset deploy key is not staged" >&2; exit 1; }

if [ "$MODE" = configure-only ]; then
  echo "Configuration validated."
  exit 0
fi
if [ "$MODE" != build ]; then
  echo "unknown mode: $MODE (expected build or configure-only)" >&2
  exit 2
fi

# lzma's Host/Clean removes only the installed binary, so force source
# re-extraction to ensure wrapper patch updates cannot leave a stale build tree.
make tools/lzma/clean
rm -rf build_dir/host/lzma-*
# Reconfigure trees generated while host AR leaked into target tool names, and
# re-extract util-linux so its NixOS-compatible shebang patch is applied.
rm -rf build_dir/target-*/apk-* build_dir/target-*/openssl-* \
  build_dir/target-*/util-linux-*
make download -j"$JOBS" V=s
make -j"$JOBS" V=s

target_dir="$OPENWRT_DIR/bin/targets/qualcommax/ipq807x"
shopt -s nullglob
factory=("$target_dir"/*linksys_mx4300*squashfs-factory.bin)
sysupgrade=("$target_dir"/*linksys_mx4300*squashfs-sysupgrade.bin)
manifests=("$target_dir"/*linksys_mx4300.manifest)
[ "${#factory[@]}" -eq 1 ] ||
  { echo "expected one MX4300 factory image, found ${#factory[@]}" >&2; exit 1; }
[ "${#sysupgrade[@]}" -eq 1 ] ||
  { echo "expected one MX4300 sysupgrade image, found ${#sysupgrade[@]}" >&2; exit 1; }
[ "${#manifests[@]}" -eq 1 ] ||
  { echo "expected one MX4300 manifest, found ${#manifests[@]}" >&2; exit 1; }
manifest="${manifests[0]}"
test -s "${factory[0]}"
test -s "${sysupgrade[0]}"
test -s "$manifest"

rootfs="$(find "$OPENWRT_DIR/build_dir" -path '*/root-qualcommax/etc/dropbear/authorized_keys' -print -quit)"
test -n "$rootfs"
cmp "$ROOT/files/etc/dropbear/authorized_keys" "$rootfs"
grep -Eq '^kmod-batman-adv([[:space:]-])' "$manifest"
grep -Eq '^kmod-qca-nss-drv-wifi-meshmgr([[:space:]-])' "$manifest"
grep -Eq '^lldpd([[:space:]-])' "$manifest"
grep -Eq '^luci-app-mesh-topology([[:space:]-])' "$manifest"
grep -Eq '^wpad-mesh-openssl([[:space:]-])' "$manifest"

cp "$ROOT/versions.env" "$target_dir/source-versions.txt"
cp "$ROOT/feeds.conf.lock" "$target_dir/feeds.lock"
cp "$ROOT/patches/102-lzma-modern-compiler.patch" \
  "$target_dir/wrapper-lzma-modern-compiler.patch"
cp "$ROOT/patches/103-golang-preserve-go-ldso.patch" \
  "$target_dir/wrapper-golang-preserve-go-ldso.patch"
{
  echo "source_commit=$(git rev-parse HEAD)"
} > "$target_dir/wrapper-provenance.txt"
"$ROOT/record-provenance.sh" "$target_dir" "$target_dir/wrapper-provenance.txt"

sha256sum "${factory[0]}" "${sysupgrade[0]}"
