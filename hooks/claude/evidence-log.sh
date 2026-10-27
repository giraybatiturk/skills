#!/bin/sh
# real-hooks-managed
# PostToolUse hook for the Bash tool. Matcher: Bash. For Claude Code, add it to PostToolUse and to PostToolUseFailure.
# It appends one line to .real/evidence.jsonl for each command: id, time, command, exit code and a hash of the output tail.
# The agent cites an id in .real/claims.md to prove a DONE WHEN item. An id that is not in the log proves nothing.
# It writes only when the repo has an active contract. It never blocks. It stays silent.
# The command text is cut to 200 characters. Values that look like a token are masked. The file is local and is not committed.
# Exit code: a number in the tool response when there is one. Else 1 for a PostToolUseFailure event.
# Else REAL_EVIDENCE_EXIT_DEFAULT (default 0). The Codex example sets it to "unknown", because Codex has no failure event.
# Turn off: REAL_EVIDENCE=0.

. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/contract-lib.sh"
set -f

[ "${REAL_EVIDENCE:-1}" = 0 ] && exit 0
[ "$(rh_field tool_name)" = Bash ] || exit 0
root=$(rh_root)
[ "$(rc_status "$root")" = active ] || exit 0
cmd=$(rh_field command)
[ -n "$cmd" ] || exit 0

ev=$(rc_evidence_file "$root")
mkdir -p "$(dirname "$ev")" 2>/dev/null || exit 0

code=$(printf '%s' "$rh_input" | sed -nE 's/.*"(exit_code|exitCode|returncode)"[[:space:]]*:[[:space:]]*(-?[0-9]+).*/\2/p' | head -n 1)
if [ -z "$code" ]; then
  case $(rh_field hook_event_name) in
    PostToolUseFailure) code=1 ;;
    *) code=${REAL_EVIDENCE_EXIT_DEFAULT:-0} ;;
  esac
fi
case $code in ''|*[!0-9-]*) code=\"unknown\" ;; esac

hash_tail() { # Standard input in. A short hash out.
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -c1-16
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 | cut -c1-16
  else cksum | tr ' ' '-'; fi
}
if rh_have_jq; then
  resp=$(printf '%s' "$rh_input" | jq -c '.tool_response // .tool_output // empty' 2>/dev/null)
else
  resp=$rh_input
fi
out_hash=$(printf '%s' "$resp" | tail -c 2000 | hash_tail)

masked=$(printf '%s' "$cmd" | tr '\n' ' ' | cut -c1-200 | sed -E \
  -e 's/(gh[pousr]_|github_pat_|sk-|xox[abprs]-|AKIA|AIza)[A-Za-z0-9_-]{8,}/\1***/g' \
  -e 's/(Bearer|Basic)[[:space:]]+[A-Za-z0-9._~+\/=-]{8,}/\1 ***/g' \
  -e 's/((token|secret|password|passwd|api[_-]?key|authorization)[A-Za-z_]*[=:][[:space:]]*)[^[:space:]]+/\1***/Ig')

n=0
[ -f "$ev" ] && n=$(wc -l < "$ev" | tr -d ' ')
id="e$((n + 1))"
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '{"id":"%s","time":"%s","exit":%s,"hash":"%s","command":%s}\n' "$id" "$now" "$code" "$out_hash" "$(printf '%s' "$masked" | rh_json_str)" >> "$ev"
exit 0
