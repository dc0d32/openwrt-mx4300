#!/bin/sh

wget -qO- https://downloads.openwrt.org/snapshots/targets/qualcommax/ipq807x/config.buildinfo | grep -v CONFIG_TARGET_DEVICE_ | grep -v CONFIG_TARGET_ALL_PROFILES | grep -v CONFIG_TARGET_MULTI_PROFILE > .config
echo CONFIG_TARGET_ALL_PROFILES=n >> .config
echo CONFIG_TARGET_MULTI_PROFILE=n >> .config
echo CONFIG_TARGET_qualcommax_ipq807x_DEVICE_linksys_mx4300=y >> .config
echo CONFIG_TARGET_DEVICE_qualcommax_ipq807x_DEVICE_linksys_mx4300=y >> .config
echo CONFIG_TARGET_DEVICE_PACKAGES_qualcommax_ipq807x_DEVICE_linksys_mx4300=\"\" >> .config
#add luci
echo CONFIG_PACKAGE_luci=y >> .config

#add libpam
#echo CONFIG_PACKAGE_libpam=y >> .config

# use ccache to speed up builds
echo CONFIG_CCACHE=y >> .config

#add packages
#echo CONFIG_PACKAGE_cloudflared=y >> .config
#echo CONFIG_PACKAGE_luci-app-cloudflared=y >> .config
echo CONFIG_PACKAGE_crowdsec-firewall-bouncer=y >> .config
echo CONFIG_PACKAGE_luci-app-crowdsec-firewall-bouncer=y >> .config
echo CONFIG_PACKAGE_luci-theme-material=y >> .config
echo CONFIG_PACKAGE_luci-theme-openwrt=y >> .config
echo CONFIG_PACKAGE_luci-proto-batman-adv=y >> .config
#skip simple wpad, replace ith wpad-mesh
cat .config | grep -v "CONFIG_PACKAGE_wpad-basic-mbedtls" > .config.tmp
mv .config.tmp .config
echo CONFIG_PACKAGE_wpad-mesh-mbedtls=y >> .config
echo CONFIG_PACKAGE_adguardhome=y >> .config
echo CONFIG_PACKAGE_mdns-repeater=y >> .config

make defconfig

#skip xdp compile
cat .config | grep -v "CONFIG_PACKAGE.*xdp" > .config.tmp
mv .config.tmp .config

