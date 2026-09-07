# Reproducible OpenWrt firmware builds

This repository builds two universal MX4300 firmware profiles:

- `build.sh` retains the known NSS image used by ares and AP-1 through AP-3.
- `build-vanilla.sh` builds an official upstream OpenWrt image without NSS
  offload for controlled comparison.

Router and AP behavior is not baked into separate images; it is applied
afterward by the declarative fleet model in `dc0d32/homelab/openwrt`.

The target is specifically **Linksys MX4300 / LN1301**. MX4301 compatibility
is not claimed without separate board-level confirmation.

It also builds AP-4's separate official **TP-Link Archer C7 v2** ath79 image
with the same public recovery key. `ap4-versions.env` and
`ap4-feeds.conf.lock` pin the exact 25.12.0-rc3 source and feed commits;
`build-ap4.sh` adds Batman, mesh WiFi, LuCI and iperf3 while omitting stale
DAWN. It explicitly replaces the Archer profile's CT ath10k driver/firmware
with upstream ath10k and replaces `wpad-basic-mbedtls` with
`wpad-mesh-mbedtls`, matching the known-working AP-4 package policy.

AP-5 through AP-7 use two official OpenWrt 25.12.0 image profiles built
together: one **Netgear RBR20** image for AP-5 and one **Netgear RBS20** image
shared by AP-6 and AP-7. Both use non-CT ath10k firmware and
`wpad-mesh-mbedtls` so their third radio can provide encrypted 802.11s/Batman
backhaul without sharing client airtime.

The RBx20 device tree limits its PCIe 5 GHz radio to 5170–5350 MHz and its
integrated high-band radio to 5470–5815 MHz. The fleet therefore runs clients
on the PCIe low-band radio and binds Batman channel 149/VHT80 to the integrated
high-band radio. Radio purpose is selected by hardware path, not discovery
order.

## Immutable inputs

`versions.env` pins qosmio's OpenWrt tree to one commit. `feeds.conf.lock` pins
every feed to the exact revisions recorded by the known-running 2026-08-16
firmware artifact. Builds therefore do not depend on the current head of an
OpenWrt or feed branch.

`prepare-source.sh` clones/fetches only that source commit, checks it out
detached, and installs the locked feed configuration. `build.sh` then expands
qosmio's NSS seed, applies the MX4300/package fragment, validates load-bearing
symbols and builds.

`vanilla-versions.env` independently pins official OpenWrt 25.12.0.
`prepare-vanilla-source.sh` and `build-vanilla.sh` use a separate worktree,
feed lock and artifact provenance. The vanilla source is not patched: only
the package selection and public recovery key differ from the official
source-build recipe. Upstream's required `kmod-qca-nss-dp` Ethernet driver is
retained, but NSS offload, ECM, NSS firmware and NSS SQM packages are rejected.

The image includes the operator's **public** Dropbear deploy key so a
factory-reset node can be restored from OpenWrt's `192.168.1.1` defaults. No
private key, password or WiFi secret is embedded.

## GitHub Actions

The workflow builds the NSS MX4300, vanilla MX4300, Archer C7 and both Orbi
profiles. Each job:

1. uses an Ubuntu 24.04 runner and commit-pinned Actions;
2. checks out its pinned upstream or NSS source instead of adding a moving
   subtree;
3. caches `dl/` by source/feed lock;
4. restores and saves `.ccache` for compiler reuse;
5. uploads firmware, checksums, manifests, build information and explicit
   wrapper/source/feed provenance.

A separate AP-4 source-build job uses the official release commits and uploads
its sysupgrade image, manifest and provenance. A source build is necessary
because OpenWrt's RC package repositories changed after publication and are no
longer ABI-compatible with the pinned RC3 ImageBuilder.

The Orbi job builds both board profiles from one pinned source tree and shared
compiler cache. Separate images are required because RBR20 and RBS20 have
different flash layouts, but AP-6 and AP-7 share the same RBS20 image.

GitHub evicts caches after extended inactivity, so a build after a long gap can
still be cold. `build_dir/` and `staging_dir/` are deliberately not cached:
they are large, host-sensitive, and less reliable than OpenWrt's supported
download and compiler caches.

## Local build on Andromeda

Andromeda remains a local builder only; it is not a GitHub self-hosted runner.

```sh
./build-local.sh
```

Build the separate upstream non-NSS MX4300 image:

```sh
./build-vanilla-local.sh
```

The vanilla wrapper runs the official build commands in a clean Debian
container on Andromeda. This avoids carrying NixOS host-tool patches in the
comparison image. Andromeda remains a local builder and is not registered as
a CI runner.

On NixOS, the wrapper automatically enters the repository's `shell.nix`.
This is required because host tools such as util-linux need ncurses from
the Nix store rather than a conventional `/usr/lib` path. The shell disables
Nix's host-side format hardening because it breaks GCC's bootstrap diagnostics;
OpenWrt's own target format-security and hardening flags remain enabled.
The wrapper also preserves `GO_LDSO` through the pinned Go feed so bootstrap
tools use NixOS's real glibc loader instead of `/lib64/ld-linux-x86-64.so.2`.
Host packages built with GCC LTO use scoped `gcc-ar`, `gcc-nm`, and
`gcc-ranlib` wrappers; target packages still use OpenWrt's cross-prefixed
Binutils. A wrapper patch also changes util-linux's executed helper scripts
from `/bin/bash` to `/usr/bin/env bash`, since NixOS does not provide
`/bin/bash`.

The default persistent worktree is
`${XDG_CACHE_HOME:-~/.cache}/openwrt-mx4300/source`, so its `dl/`, `.ccache`,
toolchain and build directories survive between runs. Override the location
with `OPENWRT_CACHE_ROOT` or `OPENWRT_WORKTREE`.

The vanilla profile uses
`${XDG_CACHE_HOME:-~/.cache}/openwrt-mx4300/vanilla-source`, so building or
cleaning it cannot alter the NSS source tree.

To validate only feed resolution and final Kconfig:

```sh
./build-local.sh configure-only
./build-vanilla-local.sh configure-only
```

Build AP-4 locally with the same persistent cache strategy:

```sh
./build-ap4-local.sh
```

Build both Orbi profiles:

```sh
./build-orbi-local.sh
```

## Firmware policy

- Batman and NSS 11.4 mesh support remain enabled.
- The NSS mesh manager transitively requires NSS Wi-Fi offload. Both remain
  enabled. qosmio's incompatibility is with DSA bridge-VLAN filtering; the
  fleet instead uses VLAN subinterfaces and one bridge per VLAN.
- DAWN is omitted because it is unused and stale on AP-4.
- Avahi is omitted; `umdns` is the sole mDNS implementation.
- vnStat is omitted; collectd plus nlbwmon remain the router telemetry path.
- Router packages such as AdGuard Home, Unbound and the CrowdSec bouncer remain
  in the universal image because ares uses them. The homelab service policy
  disables them on AP roles.
- A wrapper patch changes legacy lzma's unsafe `printf(rs)` to
  `printf("%s", rs)`, allowing modern format-security checks to remain enabled.
- Every build verifies the expected images, package manifest, embedded public
  recovery key and required mesh packages before writing pinned source/feed
  provenance beside the artifacts. `wrapper-source.tar` contains the exact
  wrapper tree used, including local uncommitted changes, and its SHA-256 is
  recorded in `wrapper-provenance.txt`.
- The vanilla profile is a comparison build, not a declaration that NSS is
  retired. It keeps BATMAN V, encrypted 802.11s and the router/AP package set
  while removing only NSS offload integration.

The unidentified Omada/switch hardware is not included until its exact model
and hardware revision are known.
