#!/usr/bin/env bash
# Archive the exact wrapper tree used by a build and append its identity.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
target_dir="${1:?target directory}"
provenance="${2:?provenance file}"
archive="$target_dir/wrapper-source.tar"

mapfile -d '' -t files < <(
  git -C "$ROOT" ls-files --cached --others --exclude-standard -z |
    LC_ALL=C sort -z
)
[ "${#files[@]}" -gt 0 ]

(
  cd "$ROOT"
  printf '%s\0' "${files[@]}" |
    tar --create --file="$archive" --null --no-recursion --mtime=@0 \
      --owner=0 --group=0 --numeric-owner --files-from=-
)

if [ -n "$(git -C "$ROOT" status --porcelain)" ]; then
  wrapper_dirty=true
else
  wrapper_dirty=false
fi

base="$(mktemp)"
trap 'rm -f "$base"' EXIT
grep -v '^wrapper_' "$provenance" > "$base" || true
mv "$base" "$provenance"
trap - EXIT

{
  echo "wrapper_commit=$(git -C "$ROOT" rev-parse HEAD)"
  echo "wrapper_dirty=$wrapper_dirty"
  echo "wrapper_source_sha256=$(sha256sum "$archive" | cut -d' ' -f1)"
} >> "$provenance"
