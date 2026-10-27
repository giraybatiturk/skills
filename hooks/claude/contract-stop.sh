#!/bin/sh
# real-hooks-managed
# Stop hook for the task contract. Works in Claude Code and in Codex. Add it next to stop-gate.sh.
# While the contract is active and the worktree has changes, the agent cannot stop with a DONE WHEN item that has no proof.
# Each DONE WHEN item needs a line in .real/claims.md: "N | done | e3, e5 | note" with evidence ids that are in
# .real/evidence.jsonl and did not fail, or "N | could-not-measure | | verifier: who can verify it".
# The hook blocks with {"decision":"block","reason":...}. It reads stop_hook_active.
# After gate.max-retries blocks in a row (default 2) it lets the agent stop and warns the user.
# Bypass: REAL_ALLOW_UNVERIFIED=1. Turn off: REAL_CONTRACT_STOP=0.

. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/contract-lib.sh"
set -f

[ "${REAL_CONTRACT_STOP:-1}" = 0 ] && exit 0
[ "${REAL_ALLOW_UNVERIFIED:-}" = 1 ] && exit 0

root=$(rh_root)
[ "$(rc_status "$root")" = active ] || exit 0
cd "$root" 2>/dev/null || exit 0

sid=$(rh_field session_id)
[ -n "$sid" ] || sid=nosession
safe_sid=$(printf '%s' "$sid" | tr -c 'A-Za-z0-9_-' '_')
counter="${TMPDIR:-/tmp}/real-contract-stop-$safe_sid.count"
max=$(rh_cfg gate.max-retries)
case $max in ''|*[!0-9]*) max=2 ;; esac

count=0
if rh_true stop_hook_active; then
  [ -f "$counter" ] && count=$(cat "$counter" 2>/dev/null)
  case $count in ''|*[!0-9]*) count=0 ;; esac
else
  rm -f "$counter"
fi

# Nothing changed outside .real/ and docs/contracts/: nothing to prove.
if git rev-parse --git-dir >/dev/null 2>&1; then
  [ -z "$(git status --porcelain -uall 2>/dev/null | sed 's/^...//' | grep -v -e '^\.real/' -e '^docs/contracts/')" ] && exit 0
fi

problems=$(rc_problems "$root")
if [ -z "$problems" ]; then
  rm -f "$counter"
  exit 0
fi

if [ "$count" -ge "$max" ]; then
  rm -f "$counter"
  msg="real: the contract still has unverified DONE WHEN items after $count retries. The agent may stop. Check the result yourself."
  printf '{"systemMessage":%s}\n' "$(printf '%s' "$msg" | rh_json_str)"
  exit 0
fi

echo $((count + 1)) > "$counter"
ids=$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$(rc_evidence_file "$root")" 2>/dev/null | tail -n 8 | tr '\n' ' ')
reason="The contract has DONE WHEN items without proof. This is retry $((count + 1)) of $max.
$problems
Write one line for each item in .real/claims.md: N | done | e3, e5 | note
Or: N | could-not-measure | | verifier: who can verify it
Recent evidence ids: ${ids:-none}. Run the command that proves the item. Then cite its id. Do not say the task is done before that."
printf '{"decision":"block","reason":%s}\n' "$(printf '%s' "$reason" | rh_json_str)"
exit 0
