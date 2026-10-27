#!/bin/sh
# real-hooks-managed
# PostToolUse hook. Matcher for Claude Code: Edit|MultiEdit|Write. For Codex: apply_patch.
# It marks the UI as changed. When an edit touches a UI file, it writes the time (epoch seconds) to .real/ui-dirty
# in the repo root. The Stop hook real-ui-stop.sh reads that file. It never blocks and never prints.
# UI files: ui.globs, a comma list of patterns (default *.tsx,*.jsx,*.css,*.scss,*.html,*.vue,*.svelte).
# The match uses case patterns, so * also matches /. A path in the repo is matched as a path relative to the repo root.
# A path outside the repo is skipped. Codex: the paths come from the lines "*** Update File:", "*** Add File:",
# "*** Delete File:" and "*** Move to:" of the patch.
# Keys: ui.url (the dev server URL; without it the hook does nothing) and ui.globs. Set them in .real-hooks, in the
# environment (REAL_UI_URL, REAL_UI_GLOBS) or with git config real.hooks.<key>. Turn off: REAL_UI_LOOP=0.

. "$(dirname "$0")/lib.sh"
set -f

[ "${REAL_UI_LOOP:-1}" = 0 ] && exit 0
[ -n "$(rh_cfg ui.url)" ] || exit 0

if [ "$(rh_field tool_name)" = apply_patch ]; then
  paths=$(rh_field command | sed -nE 's/^\*\*\* (Update File|Add File|Delete File|Move to): (.*)$/\2/p')
else
  paths=$(rh_field file_path)
fi
[ -n "$paths" ] || exit 0

globs=$(rh_cfg ui.globs)
[ -n "$globs" ] || globs='*.tsx,*.jsx,*.css,*.scss,*.html,*.vue,*.svelte'
glob_list=$(printf '%s' "$globs" | tr ',' '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
root=$(rh_root)

matches_glob() { # $1 = path relative to the repo root. Succeeds when one glob matches.
  while IFS= read -r g; do
    [ -n "$g" ] || continue
    case $1 in $g) return 0 ;; esac
  done <<GLOBS
$glob_list
GLOBS
  return 1
}

while IFS= read -r p; do
  case $p in
    "$root"/*) p=${p#"$root"/} ;; # inside the repo: relative path
    /*) continue ;;               # outside the repo
  esac
  if matches_glob "$p"; then
    { mkdir -p "$root/.real" && date +%s > "$root/.real/ui-dirty"; } 2>/dev/null
    exit 0
  fi
done <<PATHS
$paths
PATHS
exit 0
