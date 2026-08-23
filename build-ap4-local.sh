#!/usr/bin/env bash
# Persistent local AP-4 source build for Andromeda or another NixOS host.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CACHE_ROOT="${OPENWRT_CACHE_ROOT:-${XDG_CACHE_HOME:-$HOME/.cache}/openwrt-mx4300}"
OPENWRT_DIR="${AP4_OPENWRT_WORKTREE:-$CACHE_ROOT/ap4/source}"

if [[ -z "${IN_NIX_SHELL:-}" ]]; then
  printf -v command '%q ' "$0" "$@"
  exec nix-shell "$ROOT/shell.nix" --run "$command"
fi

mkdir -p "$CACHE_ROOT/ap4"
"$ROOT/prepare-ap4-source.sh" "$OPENWRT_DIR"
exec "$ROOT/build-ap4.sh" "$OPENWRT_DIR" "${1:-build}"
