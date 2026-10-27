#!/bin/sh
# real-hooks-managed
# Stop hook: the UI before and after gate. Works in Claude Code and in Codex.
# When the agent wants to stop and a UI file changed after the last real-shot capture, it blocks the stop once with
# {"decision":"block","reason":...}. The reason tells the agent to run real-shot --after and give the comparison link.
# State, in .real/ of the repo root: ui-dirty (written by real-ui-track.sh), ui-shot (written by real-shot.mjs after a
# successful after capture) and ui-nagged (the ui-dirty value that this hook already blocked for). Each holds epoch seconds.
# The hook blocks when ui-dirty is newer than ui-shot and is not the value in ui-nagged. So it blocks at most once for each
# UI edit time stamp. A new UI edit writes a new stamp, and the next stop blocks again.
# Loop safety: when stop_hook_active is true, the hook lets the agent stop.
# Key: ui.url (the dev server URL; without it the hook does nothing). Set it in .real-hooks, in the environment (REAL_UI_URL)
# or with git config real.hooks.ui.url. Turn off: REAL_UI_LOOP=0.

. "$(dirname "$0")/lib.sh"
set -f

[ "${REAL_UI_LOOP:-1}" = 0 ] && exit 0
rh_true stop_hook_active && exit 0
url=$(rh_cfg ui.url)
[ -n "$url" ] || exit 0

root=$(rh_root)
num() { # $1 = file. Prints the epoch seconds in it, or 0 when the file is missing or holds no number.
  n=$(head -n 1 "$1" 2>/dev/null | tr -d '[:space:]')
  case $n in ''|*[!0-9]*|?????????????*) n=0 ;; esac
  printf '%s\n' "$n"
}
dirty=$(num "$root/.real/ui-dirty")
shot=$(num "$root/.real/ui-shot")
nagged=$(num "$root/.real/ui-nagged")

[ "$dirty" -gt "$shot" ] && [ "$dirty" -ne "$nagged" ] || exit 0
{ printf '%s\n' "$dirty" > "$root/.real/ui-nagged"; } 2>/dev/null

here=$(cd "$(dirname "$0")" && pwd -P)
js=$(cd "$here/../../skills/engineering/real-test/scripts" 2>/dev/null && pwd -P)/real-shot.mjs
[ -f "$js" ] || js='<real-test skill>/scripts/real-shot.mjs'

reason="UI files changed after the last real-shot capture. Run real-shot before you finish: node $js --url $url --tag <tag> --after. Then give the comparison link and the numbers."
printf '{"decision":"block","reason":%s}\n' "$(printf '%s' "$reason" | rh_json_str)"
exit 0
