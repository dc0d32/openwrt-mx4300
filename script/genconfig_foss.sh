#!/bin/sh

set -x

if [ ! -z "$1" -a "$1" != "snapshot" ]; then
  buildinfo="https://downloads.openwrt.org/releases/$1/targets/qualcommax/ipq807x/config.buildinfo"
else
  buildinfo="https://downloads.openwrt.org/snapshots/targets/qualcommax/ipq807x/config.buildinfo"
fi

wget $buildinfo -O - | grep -v CONFIG_TARGET_DEVICE_ | grep -v CONFIG_TARGET_ALL_PROFILES | grep -v CONFIG_TARGET_MULTI_PROFILE > .config

echo "
CONFIG_TARGET_ALL_PROFILES=n 
CONFIG_TARGET_MULTI_PROFILE=n
CONFIG_TARGET_qualcommax_ipq807x_DEVICE_linksys_mx4300=y
CONFIG_TARGET_DEVICE_qualcommax_ipq807x_DEVICE_linksys_mx4300=y
CONFIG_TARGET_DEVICE_PACKAGES_qualcommax_ipq807x_DEVICE_linksys_mx4300=\"\"
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-proto-batman-adv=y
CONFIG_PACKAGE_adguardhome=y
CONFIG_PACKAGE_mdns-repeater=y
CONFIG_PACKAGE_iperf3=y
# - SQM: Smart Queue Management for bufferbloat control.
CONFIG_PACKAGE_luci-app-sqm=y
# - Statistics: Monitor your router’s performance (CPU, memory, bandwidth).
CONFIG_PACKAGE_luci-app-statistics=y
# - ACME: Automated SSL cert management. If you want to access your router via HTTPS and have a domain.
CONFIG_PACKAGE_luci-app-acme=y
# - Watchcat: Automate reboots on connection loss.
CONFIG_PACKAGE_luci-app-watchcat=y
# - WireGuard: VPN support. Will also select the kernel module.
CONFIG_PACKAGE_luci-proto-wireguard=y
# - NLBWMon: Network usage monitoring to track bandwidth by host.
CONFIG_PACKAGE_luci-app-nlbwmon=y
# - htop: CLI tool to monitor system resource usage.
CONFIG_PACKAGE_htop=y
# lm-sensors isn't needed for IPQ807x devices.
CONFIG_HTOP_LMSENSORS=n
" >> .config

make defconfig

#add libpam
#echo CONFIG_PACKAGE_libpam=y >> .config

#skip xdp compile
#cat .config | grep -v "CONFIG_PACKAGE.*xdp" > .config.tmp
#cp .config.tmp .config

