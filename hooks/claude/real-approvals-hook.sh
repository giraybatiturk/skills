#!/bin/sh
# real-hooks-managed
# PreToolUse hook for every tool (matcher "*"). Works in Claude Code and in Codex.
# It reads the approvals table (see hooks/README.md, "Approvals table") and decides for the tool call:
#   deny: exit 2 with the rule id and the reason.
#   ask:  a JSON "ask" with the rule id and the reason. An unlisted MCP tool with a write verb asks too (id default-write).
#   auto or no rule: no output. The table only adds restrictions. It never prints "allow".
# Set REAL_ASK_MODE=deny for a client that does not support "ask" (Codex). Then every ask becomes a deny with a grant hint.
# No table: the hook does nothing. A table with an error: every MCP write tool asks and a warning is shown.
# The agent cannot write the table or the grants folder, and cannot run "real-approvals.sh grant".

. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/real-approvals-lib.sh"
set -f

# The first string value of a top-level key. lib.sh rh_field takes the last match without jq, so a tool argument could fake the key.
ra_top() { # $1 = key
  if rh_have_jq; then
    printf '%s' "$rh_input" | jq -r --arg k "$1" 'if type == "object" and ((.[$k]) | type) == "string" then .[$k] else empty end' 2>/dev/null
  else
    printf '%s' "$rh_input" | LC_ALL=C awk -v k="$1" '
      { s = s (NR > 1 ? "\n" : "") $0 }
      END {
        pat = "\"" k "\""
        while ((p = index(s, pat)) > 0) {
          s = substr(s, p + length(pat))
          if (match(s, /^[ \t\r\n]*:[ \t\r\n]*"/)) {
            s = substr(s, RLENGTH + 1)
            match(s, /^([^"\\]|\\.)*/)
            v = substr(s, 1, RLENGTH)
            gsub(/\\\\/, "\001", v); gsub(/\\"/, "\"", v); gsub(/\\\//, "/", v); gsub(/\\n/, "\n", v); gsub(/\\t/, "\t", v); gsub(/\001/, "\\", v)
            printf "%s", v
            exit
          }
        }
      }'
  fi
}

tool=$(ra_top tool_name)
[ -n "$tool" ] || exit 0
cwd=$(ra_top cwd)
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd=.
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || root=$cwd

ra_load "$root"
[ -n "$RA_FILES" ] || exit 0

# Self-protection. The guard never asks.
# Text is lower case, without a backslash-newline pair (the shell joins the words) and without the characters " ' \ and $ (so gr''ant and \grant read as grant), with "//" and "/./" collapsed.
guard_deny() { rh_block "The approvals table and the grants folder are for the user only. Read the rules with real-approvals.sh check or explain. Only the user runs grant, in a terminal."; }
# Newline and backslash become \001 and \002 first, so sed can drop the pair \002\001 on one line.
norm() { tr 'A-Z' 'a-z' | tr '\n\134' '\001\002' | LC_ALL=C sed "s/$(printf '\002\001')//g" | tr '\001' '\n' | tr -d '\002\042\047\044' | LC_ALL=C awk '{ do { t = $0; gsub(/\/\/+/, "/"); gsub(/\/\.\//, "/") } while (t != $0); print }'; }

# The physical path of $1: links followed (at most 8 hops) and the folder resolved with cd -P (this also removes "..").
# A path in a missing folder stays as it is.
phys() {
  ph=$1; hops=0
  while :; do
    pd=$(cd -P -- "$(dirname -- "$ph")" 2>/dev/null && pwd -P) || pd=$(dirname -- "$ph")
    ph=${pd%/}/$(basename -- "$ph")
    [ -L "$ph" ] && [ "$hops" -lt 8 ] || break
    lk=$(readlink "$ph") || break
    case $lk in /*) ph=$lk ;; *) ph=${pd%/}/$lk ;; esac
    hops=$((hops + 1))
  done
  printf '%s\n' "$ph"
}

# The table paths as given and as physical paths (the user table can be a link to a file in another folder), one for each line.
# in_list adds the last two components of each physical path, for text that holds a relative path.
phys_files=$(printf '%s\n' "$RA_FILES" | while IFS= read -r f; do phys "$f"; done | norm)
needles=$({ [ -z "${REAL_APPROVALS:-}" ] || printf '%s\n' "$REAL_APPROVALS"; printf '%s\n%s\n' "$RA_FILES" "$phys_files"; } | norm)
tails=$(printf '%s\n' "$phys_files" | while IFS= read -r f; do b=${f##*/}; d=${f%/*}; printf '%s/%s\n' "${d##*/}" "$b"; done)
in_list=$needles'
'$tails

# $1 = normalised text, $2 = in (the text holds a table path) or is (the text is a table path).
names_table() {
  case $1 in *real/approvals*) return 0 ;; esac
  if [ "$2" = in ]; then ml=$in_list; else ml=$needles; fi
  while IFS= read -r v; do
    [ -n "$v" ] || continue
    if [ "$2" = in ]; then case $1 in *"$v"*) return 0 ;; esac
    elif [ "$1" = "$v" ]; then return 0; fi
  done <<EOF
$ml
EOF
  return 1
}

cmd=
case $tool in
  Bash|apply_patch)
    cmd=$(rh_field command)
    n=$(printf '%s' "$cmd" | norm)
    names_table "$n" in && guard_deny
    if printf '%s\n' "$n" | grep -Eq 'real-approvals(\.sh)?[[:space:]]+grant([[:space:]]|$)'; then guard_deny; fi
    ;;
  Read|Grep|Glob) ;;
  *)
    for key in file_path notebook_path path; do
      p=$(rh_field "$key")
      [ -n "$p" ] || continue
      case $p in /*) ;; *) p=$cwd/$p ;; esac
      n=$(printf '%s' "$p" | norm)
      names_table "$n" is && guard_deny
      n=$(phys "$p" | norm)
      names_table "$n" is && guard_deny
    done
    ;;
esac

[ "$tool" = Bash ] || cmd=
ra_decide "$tool" "$cmd"

case $RA_MODE in
  deny)
    msg="$RA_ID: $RA_WHY"
    [ -z "$RA_BTXT" ] || [ "$RA_ID" = broken-table ] || msg="$msg Also, $RA_BTXT"
    rh_block "$msg"
    ;;
  ask)
    if [ "${REAL_ASK_MODE:-ask}" = deny ]; then
      if [ "$RA_ID" = broken-table ]; then hint="Fix the table: real-approvals.sh check"
      else hint="The user can allow the rule for a time with: real-approvals.sh grant $RA_ID --minutes 10"; fi
      msg="$RA_ID: $RA_WHY This client cannot ask. $hint"
      [ -z "$RA_BTXT" ] || [ "$RA_ID" = broken-table ] || msg="$msg Also, $RA_BTXT"
      rh_block "$msg"
    fi
    reason=$(printf '%s' "$RA_ID: $RA_WHY" | rh_json_str)
    if [ -n "$RA_BTXT" ]; then
      sm=$(printf '%s' "real: $RA_BTXT" | rh_json_str)
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":%s},"systemMessage":%s}\n' "$reason" "$sm"
    else
      printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":%s}}\n' "$reason"
    fi
    ;;
  *)
    if [ -n "$RA_BTXT" ]; then
      sm=$(printf '%s' "real: $RA_BTXT" | rh_json_str)
      printf '{"systemMessage":%s}\n' "$sm"
    fi
    ;;
esac
exit 0
