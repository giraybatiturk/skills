#!/bin/sh
# real-hooks-managed
# SessionStart hook. It gives the agent the active contract: task, status, SCOPE and DO NOT TOUCH. At most 1200 characters.
# Without a contract it stays silent, unless contract.required is "always". Then it says "no contract".
# It works in Claude Code and in Codex. Turn off: REAL_CONTRACT_START=0.

. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/contract-lib.sh"
set -f

[ "${REAL_CONTRACT_START:-1}" = 0 ] && exit 0
root=$(rh_root)
status=$(rc_status "$root")
f=$(rc_file "$root")
if [ -z "$status" ]; then
  [ "$(rh_cfg contract.required)" = always ] || exit 0
  msg="real: no contract. Write one with the real-plan contract mode and ask the user to approve it before you change files."
else
  one_line() { rc_section "$f" "$1" | tr '\n' ',' | sed -e 's/,$//' -e 's/,/, /g'; }
  msg="real contract '$(rc_header "$f" Task)' ($status). SCOPE: $(one_line SCOPE). DO NOT TOUCH: $(one_line 'DO NOT TOUCH')."
  case $status in
    draft) msg="$msg The contract is a draft. It is not enforced. Wait for the user to approve it." ;;
    active) msg="$msg Edits outside SCOPE need the user. Prove each DONE WHEN item in .real/claims.md." ;;
  esac
fi
msg=$(printf '%s' "$msg" | cut -c1-1200)
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' "$(printf '%s' "$msg" | rh_json_str)"
exit 0
