#!/bin/sh
# real-status.sh: print the state of the work in 8 lines or less. No network, no model call.
#
# Usage:
#   real-status.sh [DIR]
#   real-status.sh -h | --help
#
# DIR is a folder of the repo. The default is the current folder. The lines, in this order (a line with no data is skipped):
#   <branch>  <N> changed, last commit <age> ago   or   git: not a git repo (<dir>)
#   contract: <task> (<status>), <v> of <n> items verified   or   contract: none
#   last: <command> (exit <code>), <command> (<code>), ...
#   turn: <state> <age> ago - "<request>"   or   turn: running for <age> - "<request>"
#   jobs at last stop: <job>; <job>
# Sources: git, .real/contract.md, .real/claims.md, .real/evidence.jsonl (the last 3 lines), and the turn log
# that hooks/claude/real-turn-log.sh writes in ${XDG_STATE_HOME:-$HOME/.local/state}/real/turn/.
# Every line is cleaned, masked and cut to 160 characters.
# Exit codes: 0 ok, 2 bad input (an unknown flag, more than one folder, or a DIR that is not a folder).

set -f
unset CDPATH

usage() { sed -n '2,/^$/p' "$0" | sed -e '$d' -e 's/^# \{0,1\}//'; }
case ${1:-} in
  -h|--help) usage; exit 0 ;;
  -*) usage >&2; exit 2 ;;
esac
[ $# -le 1 ] || { usage >&2; exit 2; }

. "$(dirname "$0")/../hooks/claude/real-state-lib.sh"

[ -d "${1:-.}" ] || { printf 'real-status: no such folder: %s\n' "$(printf '%s' "$1" | rs_clean)" >&2; exit 2; }

have_jq() { [ -z "${REAL_NO_JQ:-}" ] && command -v jq >/dev/null 2>&1; }
emit() { printf '%s\n' "$1" | head -n 1 | rs_clean | rs_mask | rs_cut 160; }
# A line built from parts that are masked already. A second mask would eat the closing quote after a "key=***" value.
emit_masked() { printf '%s\n' "$1" | head -n 1 | rs_clean | rs_cut 160; }

root=$(rs_root "${1:-.}")
[ -n "$root" ] || root=${1:-.}
now=$(date +%s)

# 1. Git
if [ "$(git -C "$root" rev-parse --is-inside-work-tree 2>/dev/null)" = true ]; then
  br=$(git -C "$root" symbolic-ref --short -q HEAD)
  n=$(git -C "$root" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if git -C "$root" rev-parse --verify -q HEAD >/dev/null 2>&1; then
    [ -n "$br" ] || br=$(git -C "$root" rev-parse --short HEAD)
    t=$(git -C "$root" log -1 --format=%ct 2>/dev/null)
    if rs_num "$t"; then c="last commit $(rs_age "$now" "$t") ago"; else c="last commit unknown"; fi
  else
    c="no commits"
  fi
  emit "${br:-HEAD}  $n changed, $c"
else
  emit "git: not a git repo ($root)"
fi

# 2. Contract. rs_contract counts the verified items: the same rule as in the report of the contract.
ev=$root/.real/evidence.jsonl
if rs_contract "$root"; then
  emit "contract: ${rs_task:-untitled} (${rs_status:-no status}), $rs_verified of $rs_total items verified"
else
  emit "contract: none"
fi

# 3. Last commands. The log is made by evidence-log.sh: {"id":..,"time":..,"exit":0,"hash":..,"command":".."}
if [ -f "$ev" ]; then
  raw_last() { # prints "<code> <command>" for each of the last 3 lines
    if have_jq; then
      # A separator byte after each entry keeps a command with a newline on one line. -R reads each line on its own: a bad line is skipped.
      tail -n 3 "$ev" | jq -R -j 'fromjson? | objects | "\(.exit) \(.command)\u0001"' 2>/dev/null | tr '\n\001' ' \n'
    else
      tail -n 3 "$ev" | sed -nE 's/^.*"exit":"?([A-Za-z0-9-]+)"?,.*"command":"(.*)"\}[[:space:]]*$/\1 \2/p' |
        awk '{ gsub(/\\\\/, "\001"); gsub(/\\"/, "\""); gsub(/\\[nrt]/, " "); gsub(/\\\//, "/"); gsub(/\001/, "\\"); print }'
    fi
  }
  fmt_last() { # stdin: "<code> <command>" lines. Prints one line. A command is masked, then cut to 40 characters.
    out=
    while read -r code cmd; do
      [ -n "$code" ] || continue
      case $code in *[!A-Za-z0-9-]*) code='?' ;; esac
      cmd=$(printf '%s' "$cmd" | rs_clean | rs_mask | rs_cut 40)
      if [ -z "$out" ]; then out="$cmd (exit $code)"; else out="$out, $cmd ($code)"; fi
    done
    printf '%s' "$out"
  }
  last=$(raw_last | fmt_last)
  [ -n "$last" ] && emit "last: $last"
fi

# 4. Turn, and 5. Jobs. Both come from the state folder of this root.
sd=$(rs_dir "$root")
ts=$(rs_read "$sd" turn_start "$root")
te=$(rs_read "$sd" turn_end "$root")
rs_num "$ts" || ts=
rs_num "$te" || te=
if [ -z "$ts" ] && [ -z "$te" ]; then
  emit "turn: no record"
else
  rq=$(rs_read "$sd" last_request "$root" | rs_clean | rs_mask)
  if [ -n "$te" ] && { [ -z "$ts" ] || [ "$te" -ge "$ts" ]; }; then
    line="turn: $(rs_read "$sd" state "$root" | rs_clean | rs_mask)"
    [ "$line" = "turn: " ] && line="turn: ended"
    line="$line $(rs_age "$now" "$te") ago"
  else
    line="turn: running for $(rs_age "$now" "$ts")"
  fi
  [ -n "$rq" ] && line="$line - \"$rq\""
  emit_masked "$line"
  if rs_owned "$sd" "$root" && [ -f "$sd/jobs" ]; then
    jobs=$(head -n 5 "$sd/jobs" | awk 'NF { printf "%s%s", (c++ ? "; " : ""), $0 }')
    [ -n "$jobs" ] && emit "jobs at last stop: $jobs"
  fi
fi
exit 0
