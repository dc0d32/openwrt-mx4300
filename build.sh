#!/bin/sh
# for WSL, run this
# export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/usr/lib/wsl/lib

./scripts/feeds update
./scripts/feeds install -a

cp nss-setup/config-nss.seed .config

echo "
CONFIG_TARGET_qualcommax_ipq807x_DEVICE_linksys_mx4300=y
CONFIG_FEED_nss_packages=n
" >> .config

#####################################################################
# My packages
#####################################################################

# NSS related
echo "CONFIG_NSS_MEM_PROFILE_HIGH=y" >> .config
echo "CONFIG_NSS_DRV_CRYPTO_ENABLE=y" >> .config
echo "CONFIG_PACKAGE_kmod-qca-nss-crypto=y" >> .config
echo "CONFIG_NSS_DRV_GRE_ENABLE=y" >> .config
echo "CONFIG_PACKAGE_kmod-qca-nss-drv-eogremgr=y" >> .config
echo "CONFIG_PACKAGE_kmod-qca-nss-drv-gre=y" >> .config
echo "CONFIG_NSS_DRV_IGS_ENABLE=y" >> .config
echo "CONFIG_PACKAGE_kmod-qca-nss-drv-igs=y" >> .config

echo "CONFIG_NSS_DRV_WIFI_MESH_ENABLE=y" >> .config
echo "CONFIG_NSS_DRV_WIFIOFFLOAD_ENABLE=y" >> .config
echo "CONFIG_PACKAGE_kmod-qca-nss-drv-wifi-meshmgr=y" >> .config

echo "CONFIG_NSS_DRV_SHAPER_ENABLE=y" >> .config
echo "CONFIG_NSS_DRV_VLAN_ENABLE=y" >> .config

# extra packages
echo "CONFIG_PACKAGE_luci-proto-batman-adv=y" >> .config
echo "CONFIG_PACKAGE_batctl-full=y" >> .config
echo "CONFIG_PACKAGE_adguardhome=y" >> .config
echo "CONFIG_PACKAGE_luci-app-unbound=y" >> .config
echo "CONFIG_PACKAGE_unbound-control=y" >> .config
# echo "CONFIG_PACKAGE_mdns-repeater=y" >> .config # disabled. Using avahi instead
# avahi
echo "CONFIG_PACKAGE_avahi-dbus-daemon=y" >> .config
echo "CONFIG_PACKAGE_iperf3=y" >> .config
echo "CONFIG_PACKAGE_tmux=y" >> .config
echo "CONFIG_PACKAGE_luci-app-wol=y" >> .config

# echo "CONFIG_PACKAGE_crowdsec=y" >> .config
echo "CONFIG_PACKAGE_luci-app-crowdsec-firewall-bouncer=y" >> .config
echo "CONFIG_PACKAGE_luci-app-vnstat2=y" >> .config

# echo "CONFIG_PACKAGE_zabbix-agentd=y" >> .config
# echo "CONFIG_PACKAGE_zabbix-extra-mac80211=y" >> .config
# echo "CONFIG_PACKAGE_zabbix-extra-network=y" >> .config
# echo "CONFIG_PACKAGE_zabbix-extra-wifi=y" >> .config

# echo "CONFIG_PACKAGE_freeradius3=y" >> .config
# echo "CONFIG_PACKAGE_freeradius3-utils=y" >> .config

# USB printer
# echo "CONFIG_PACKAGE_luci-app-p910nd=y" >> .config
# echo "CONFIG_PACKAGE_kmod-usb-printer=y" >> .config

# WireGuard
echo "CONFIG_PACKAGE_qrencode=y" >> .config

# build
make defconfig

cat .config | grep kmod-qca | grep -v "not set"

