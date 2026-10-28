#!/usr/bin/env bash
# Generate a tool pointer file (for example an AGENTS.md) that loads real.md first,
# then the owner's private real.local.md if one exists.
# Never overwrites silently: an existing target is copied to a dated backup first,
# and a symlink target is refused.
#
# Usage:
#   bash scripts/install-real-md.sh --print [OVERLAY_DIR]        print to stdout, write nothing
#   bash scripts/install-real-md.sh TARGET_FILE [OVERLAY_DIR]    back up TARGET_FILE, then write it
#
# OVERLAY_DIR holds real.local.md and real.local/ (kept in a private repository, not in this one).
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd -P)
target=${1:?Usage: bash scripts/install-real-md.sh (--print | TARGET_FILE) [OVERLAY_DIR]}
overlay=${2:-}
[[ -f "$repo/real.md" && -d "$repo/real" ]] || { printf 'Incomplete checkout: real.md or real/ missing.\n' >&2; exit 1; }
render() {
  cat "$repo/real.md"
  if [[ -n "$overlay" && -f "$overlay/real.local.md" ]]; then
    printf '\n'
    cat "$overlay/real.local.md"
  fi
  printf '\nIndex paths resolve against these absolute directories, not against this file:\n'
  printf -- '- real/ = %s/real/\n' "$repo"
  if [[ -n "$overlay" && -d "$overlay/real.local" ]]; then
    printf -- '- real.local/ = %s/real.local/\n' "$(cd "$overlay" && pwd -P)"
  fi
}
if [[ "$target" == "--print" ]]; then
  render
  exit 0
fi
if [[ -L "$target" ]]; then
  printf 'Target is a symlink: %s. Resolve it yourself, then retry.\n' "$target" >&2
  exit 1
fi
if [[ -e "$target" ]]; then
  backup="$target.bak-$(date +%Y%m%d-%H%M%S)"
  cp -p "$target" "$backup"
  printf 'Backed up %s to %s\n' "$target" "$backup"
fi
tmp=$(mktemp "${target}.XXXXXX")
render > "$tmp"
mv "$tmp" "$target"
printf 'Wrote %s (real.md first, then the overlay if given).\n' "$target"
