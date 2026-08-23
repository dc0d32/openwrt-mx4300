#!/usr/bin/env bash
# Persistent local build path for Andromeda or another operator workstation.
# This is deliberately local-only; it does not register a GitHub runner.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CACHE_ROOT="${OPENWRT_CACHE_ROOT:-${XDG_CACHE_HOME:-$HOME/.cache}/openwrt-mx4300}"
OPENWRT_DIR="${OPENWRT_WORKTREE:-$CACHE_ROOT/source}"

if [[ -z "${IN_NIX_SHELL:-}" ]]; then
  printf -v command '%q ' "$0" "$@"
  exec nix-shell "$ROOT/shell.nix" --run "$command"
fi

mkdir -p "$CACHE_ROOT"
"$ROOT/prepare-source.sh" "$OPENWRT_DIR"
exec "$ROOT/build.sh" "$OPENWRT_DIR" "${1:-build}"
