#!/bin/sh
# Install the git hooks of the real skills into one repo. POSIX sh. Needs git only.
#
# Usage:
#   scripts/install-hooks.sh [--print] [--uninstall] [--hooks-path DIR] REPO
#
#   REPO              The repo to change. The script changes only this repo.
#   --hooks-path DIR  Copy the hooks into DIR and set core.hooksPath of REPO (local config) to DIR.
#                     Without this option the script copies the hooks into the hooks folder of REPO.
#   --print           Dry run. Print what the script would do. Change nothing.
#   --uninstall       Remove the real hooks. Restore the newest backup of each hook, when one exists.
#
# The script backs up every existing hook that is not a real hook. The backup name is
# <hook>.real-backup-YYYYmmddHHMMSS in the same folder.
# The script never edits ~/.claude/settings.json, ~/.codex or the global git config.
# At the end it prints the Claude Code settings snippet. Copy it by hand.

set -eu

dry=no
uninstall=no
hookspath=
repo=

while [ $# -gt 0 ]; do
  case $1 in
    --print) dry=yes ;;
    --uninstall) uninstall=yes ;;
    --hooks-path) shift; [ $# -gt 0 ] || { echo "install-hooks: --hooks-path needs a folder." >&2; exit 2; }; hookspath=$1 ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "install-hooks: unknown option: $1" >&2; exit 2 ;;
    *) repo=$1 ;;
  esac
  shift
done
[ -n "$repo" ] || { echo "install-hooks: give the repo path. Use --help for the usage." >&2; exit 2; }

here=$(cd "$(dirname "$0")" && pwd)
src=$here/../hooks/git
claude_dir=$(cd "$here/../hooks/claude" && pwd)
[ -d "$src" ] || { echo "install-hooks: hooks/git was not found next to this script." >&2; exit 1; }
src=$(cd "$src" && pwd)

git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || { echo "install-hooks: '$repo' is not a git repo." >&2; exit 1; }
top=$(git -C "$repo" rev-parse --show-toplevel)
stamp=$(date +%Y%m%d%H%M%S)

say() { if [ "$dry" = yes ]; then printf 'would: %s\n' "$*"; else printf '%s\n' "$*"; fi; }
do_it() { [ "$dry" = yes ] || "$@"; }

current_path=$(git -C "$top" config --local --get core.hooksPath 2>/dev/null || true)

if [ -n "$hookspath" ]; then
  case $hookspath in /*) dest=$hookspath ;; *) dest=$(pwd)/$hookspath ;; esac
else
  if [ -n "$current_path" ]; then
    echo "install-hooks: core.hooksPath is already set to '$current_path' in this repo." >&2
    echo "Use --hooks-path with a folder, or unset core.hooksPath first. Nothing was changed." >&2
    exit 1
  fi
  gp=$(git -C "$top" rev-parse --git-path hooks)
  case $gp in /*) dest=$gp ;; *) dest=$top/$gp ;; esac
fi

hooks=$(ls "$src")

if [ "$uninstall" = yes ]; then
  for h in $hooks; do
    f=$dest/$h
    if [ -f "$f" ] && grep -q 'real-hooks-managed' "$f"; then
      say "remove $f"
      do_it rm -f "$f"
      b=$(ls -1 "$dest/$h".real-backup-* 2>/dev/null | sort | tail -n 1 || true)
      if [ -n "$b" ]; then
        say "restore $b -> $f"
        do_it mv "$b" "$f"
      fi
    fi
  done
  if [ -n "$hookspath" ] && [ "$(git -C "$top" config --local --get core.hooksPath 2>/dev/null || true)" = "$dest" ]; then
    prev=$(git -C "$top" config --local --get real.previousHooksPath 2>/dev/null || true)
    if [ -n "$prev" ]; then
      say "set core.hooksPath back to $prev"
      do_it git -C "$top" config --local core.hooksPath "$prev"
    else
      say "unset core.hooksPath"
      do_it git -C "$top" config --local --unset core.hooksPath
    fi
    do_it git -C "$top" config --local --unset real.hooksPath || true
  fi
  [ "$dry" = yes ] && echo "Dry run. Nothing was changed." || echo "Uninstall done."
  exit 0
fi

say "hooks folder: $dest"
do_it mkdir -p "$dest"
for h in $hooks; do
  f=$dest/$h
  if [ -e "$f" ]; then
    if cmp -s "$src/$h" "$f"; then
      say "keep $h (same content)"
      continue
    fi
    if ! grep -q 'real-hooks-managed' "$f" 2>/dev/null; then
      say "back up $f -> $f.real-backup-$stamp"
      do_it cp -p "$f" "$f.real-backup-$stamp"
    fi
  fi
  say "install $h"
  do_it cp "$src/$h" "$f"
  do_it chmod +x "$f"
done
if [ -n "$hookspath" ]; then
  if [ -n "$current_path" ] && [ "$current_path" != "$dest" ]; then
    say "remember the old core.hooksPath ($current_path)"
    do_it git -C "$top" config --local real.previousHooksPath "$current_path"
  fi
  say "set core.hooksPath to $dest (local config of $top)"
  do_it git -C "$top" config --local core.hooksPath "$dest"
  do_it git -C "$top" config --local real.hooksPath "$dest"
fi

[ "$dry" = yes ] && echo "Dry run. Nothing was changed."

cat <<MSG

Optional: mark the repo as public, so that pre-push scans for private patterns:
  git -C "$top" config real.public true
Put your private patterns in ~/.config/real/private-patterns.txt (one for each line). Keep this file outside every repo.

Claude Code settings snippet. Merge it by hand into ~/.claude/settings.json or into <repo>/.claude/settings.json.
This script does not edit those files. Codex users: see hooks/codex/hooks.example.json.
MSG
sed "s|/ABSOLUTE/PATH/TO/skills/hooks/claude|$claude_dir|g" "$claude_dir/settings.example.json"
