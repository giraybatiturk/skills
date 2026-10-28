#!/bin/sh
# real-hooks-managed
# Stop hook: the "done" gate. Works in Claude Code and in Codex.
# When the agent wants to stop, it runs the typecheck, the lint and the tests of the repo.
# If one fails, it blocks the stop with {"decision":"block","reason":...}. The agent must fix the problem.
# Commands: REAL_GATE_TYPECHECK, REAL_GATE_LINT, REAL_GATE_TEST, or gate.typecheck, gate.lint, gate.test
# in .real-hooks, or git config real.hooks.gate.test. Without a setting, the hook uses the npm scripts
# "typecheck", "lint" and "test" of package.json when they exist. Without any command, the hook allows the stop.
# Loop safety: the hook reads stop_hook_active. A fresh turn (false) resets the retry count.
# After gate.max-retries blocks in a row (default 2), the hook lets the agent stop and warns the user.
# The hook skips the gate when the working tree has no change. Bypass: REAL_ALLOW_UNVERIFIED=1. Turn off: REAL_STOP_GATE=0.
# Command timeout: REAL_GATE_TIMEOUT seconds (default 240) when the timeout command exists.

. "$(dirname "$0")/lib.sh"
set -f

[ "${REAL_STOP_GATE:-1}" = 0 ] && exit 0
[ "${REAL_ALLOW_UNVERIFIED:-}" = 1 ] && exit 0

root=$(rh_root)
cd "$root" 2>/dev/null || exit 0

sid=$(rh_field session_id)
[ -n "$sid" ] || sid=nosession
safe_sid=$(printf '%s' "$sid" | tr -c 'A-Za-z0-9_-' '_')
counter="${TMPDIR:-/tmp}/real-stop-gate-$safe_sid.count"
max=$(rh_cfg gate.max-retries)
case $max in ''|*[!0-9]*) max=2 ;; esac

count=0
if rh_true stop_hook_active; then
  [ -f "$counter" ] && count=$(cat "$counter" 2>/dev/null)
  case $count in ''|*[!0-9]*) count=0 ;; esac
else
  rm -f "$counter"
fi

# Nothing changed: nothing to verify.
if git rev-parse --git-dir >/dev/null 2>&1; then
  [ -z "$(git status --porcelain 2>/dev/null)" ] && exit 0
fi

pkg_script() { # $1 = script name. Prints the npm command when package.json has the script.
  [ -f package.json ] && grep -Eq "\"$1\"[[:space:]]*:" package.json && printf 'npm run -s %s\n' "$1"
}
cmds=
for name in typecheck lint test; do
  c=$(rh_cfg "gate.$name")
  [ -z "$c" ] && c=$(pkg_script "$name")
  [ -n "$c" ] && cmds="$cmds$name	$c
"
done
[ -n "$cmds" ] || exit 0

limit=${REAL_GATE_TIMEOUT:-240}
runner=
if command -v timeout >/dev/null 2>&1; then runner="timeout $limit"
elif command -v gtimeout >/dev/null 2>&1; then runner="gtimeout $limit"; fi

fail_name=; fail_cmd=; fail_out=
TAB=$(printf '\t')
while IFS="$TAB" read -r name c; do
  [ -z "$name" ] && continue
  out=$($runner sh -c "$c" 2>&1)
  if [ $? -ne 0 ]; then
    fail_name=$name; fail_cmd=$c; fail_out=$(printf '%s' "$out" | tail -n 30)
    break
  fi
done <<CMDS
$cmds
CMDS

if [ -z "$fail_name" ]; then
  rm -f "$counter"
  exit 0
fi

if [ "$count" -ge "$max" ]; then
  rm -f "$counter"
  msg="real: the done gate still fails ($fail_name) after $count retries. The agent may stop. Check the result yourself."
  printf '{"systemMessage":%s}\n' "$(printf '%s' "$msg" | rh_json_str)"
  exit 0
fi

echo $((count + 1)) > "$counter"
reason="The done gate failed at step '$fail_name'. Command: $fail_cmd
Fix the problem, then try to finish again. This is retry $((count + 1)) of $max.
Last output:
$fail_out"
printf '{"decision":"block","reason":%s}\n' "$(printf '%s' "$reason" | rh_json_str)"
exit 0
