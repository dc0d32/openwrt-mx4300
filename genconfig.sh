#!/bin/sh

cp nss-setup/config-nss.seed .config
echo "
CONFIG_TARGET_qualcommax_ipq807x_DEVICE_linksys_mx4300=y
CONFIG_FEED_nss_packages=n
" >> .config
make defconfig

cat .config | grep kmod-qca | grep -v "not set"
