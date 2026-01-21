# OpenWRT MX4300/MX4301 Build

This repository contains configuration for building OpenWRT firmware for Linksys MX4300/MX4301 routers.

## Automated Builds

GitHub Actions automatically builds the firmware when changes are pushed to the `build` or `main` branches. The workflow can also be triggered manually from the Actions tab.

### Build Artifacts

After a successful build, the following artifacts are available for download:

- `openwrt-qualcommax-ipq807x-linksys_mx4300-squashfs-sysupgrade.bin` - Main firmware image
- `sha256sums` - Checksums for verification
- `*.buildinfo` - Build information files

### Build Process

The automated build performs the following steps:

1. Sets up an Ubuntu environment with OpenWRT build dependencies
2. Adds the qosmio remote repository (`https://github.com/qosmio/openwrt-ipq/`)
3. Adds the 25.12-nss subtree from the qosmio repository
4. Runs the build.sh configuration script
5. Downloads required packages
6. Builds the firmware using all available CPU cores
7. Uploads the firmware and related files as artifacts

## Manual Build

To build manually on your own machine:

1. Install OpenWRT build dependencies on a clean Debian/Ubuntu Linux environment
2. Clone this repository (build branch):
   ```bash
   git clone -b build https://github.com/dc0d32/openwrt-mx4300.git
   cd openwrt-mx4300
   ```
3. Add the qosmio remote and subtree:
   ```bash
   git remote add qosmio https://github.com/qosmio/openwrt-ipq/
   git subtree add --prefix 25.12-nss qosmio 25.12-nss
   ```
4. Build the firmware:
   ```bash
   cd 25.12-nss
   bash ../build.sh
   make download
   make -j$(nproc)
   ```
5. The final image will be available at:
   ```
   bin/targets/qualcommax/ipq807x/openwrt-qualcommax-ipq807x-linksys_mx4300-squashfs-sysupgrade.bin
   ```

## Configuration

The `build.sh` script configures the build with:

- NSS (Network Subsystem) acceleration support
- Various network utilities (batman-adv, WireGuard, etc.)
- Additional packages (AdGuard Home, Unbound, etc.)
- Performance optimizations (high memory profile, crypto acceleration)

See `build.sh` for the complete list of enabled features and packages.
