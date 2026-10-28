#!/bin/sh
# real-approvals.sh: check the approvals table, explain one decision, grant a rule for a time, export a block for omp.
#
# Usage:
#   real-approvals.sh check                        Print the tables, the rules, the conflicts and the grants. Exit 1 when a table has an error.
#   real-approvals.sh explain TOOL_NAME            Print the decision for a tool: MODE ID: WHY. One word such as mcp__x__y or Write is a tool name.
#   real-approvals.sh explain COMMAND...           Print the decision for a Bash command.
#   real-approvals.sh grant RULE_ID [--minutes N]  Let an ask rule pass for N minutes (1 to 1440, default 10). Run it in a terminal yourself.
#   real-approvals.sh revoke RULE_ID               Remove the grant of a rule.
#   real-approvals.sh export-omp [--tools FILE]    Print the omp tools.approval block. It writes no file. FILE has one tool name for each line ("-" is stdin).
#   real-approvals.sh --help
#
# Tables: REAL_APPROVALS (this file only), or .real/approvals.yml in the repo and ${XDG_CONFIG_HOME:-$HOME/.config}/real/approvals.yml together.
# Grants: ${XDG_STATE_HOME:-$HOME/.local/state}/real/approvals/RULE_ID. Exit codes: 0 ok, 1 refused or broken table, 2 bad usage.

set -f
umask 077
unset CDPATH

here=$(cd "$(dirname "$0")" && pwd)
. "$here/../hooks/claude/real-approvals-lib.sh"

die() { c=$1; shift; printf 'real-approvals: %s\n' "$*" >&2; exit "$c"; }
usage() { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; }

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

valid_id() { # a rule id: a-z, 0-9 and -, at most 64 characters
  case $1 in ''|*[!a-z0-9-]*|-*) return 1 ;; esac
  [ ${#1} -le 64 ]
}

# The strictest mode of the rules with this id in the loaded tables: deny, ask, auto or none.
rule_mode() {
  printf '%s\n' "$RA_REC" | LC_ALL=C awk -F '\001' -v id="$1" '$1 == "R" && $3 == id { if ($5 == "deny") d = 1; else if ($5 == "ask") a = 1; else u = 1 } END { print (d ? "deny" : (a ? "ask" : (u ? "auto" : "none"))) }'
}

do_check() {
  ra_load "$root"
  if [ -z "$RA_FILES" ]; then
    printf 'no approvals table found. Looked at: %s, %s\n' "$(ra_repo_table "$root")" "$(ra_user_table)" | ra_clean
    return 0
  fi
  rc=0
  out=$({ printf '%s\n' "$RA_REC"; printf '\003'; } | LC_ALL=C awk "$RA_AWK_COMMON
$RA_AWK_REPORT") || rc=$?
  [ -n "$out" ] || die 1 "the report is empty. Check that awk works."
  printf '%s\n' "$out" | ra_clean
  ra_grant_scan list | while read -r gid gst; do
    case $gst in
      expired) printf 'grant %s: expired\n' "$gid" ;;
      invalid) printf 'grant %s: invalid\n' "$gid" ;;
      *) printf 'grant %s: %s min left\n' "$gid" "$gst" ;;
    esac
  done
  return $rc
}

do_explain() {
  [ $# -gt 0 ] || die 2 "explain needs a tool name or a command"
  arg=$*
  etool=Bash; ecmd=$arg
  if [ $# -eq 1 ]; then
    case $arg in
      *'
'*) ;;
      *) if printf '%s\n' "$arg" | grep -Eq '^(mcp__[A-Za-z0-9_.:-]+|[A-Z][A-Za-z0-9_]*|apply_patch)$'; then etool=$arg; ecmd=; fi ;;
    esac
  fi
  ra_load "$root"
  if [ -z "$RA_FILES" ]; then printf 'auto none: No approvals table found.\n'; return 0; fi
  ra_decide "$etool" "$ecmd"
  line="$RA_MODE $RA_ID: $RA_WHY"
  [ -z "$RA_GRANT" ] || line="$line (granted, $RA_GRANT min left)"
  printf '%s\n' "$line"
}

do_grant() {
  [ -t 0 ] || die 1 "grant needs a terminal. Run it yourself, not through an agent."
  gid=; mins=10
  while [ $# -gt 0 ]; do
    case $1 in
      --minutes) [ $# -ge 2 ] || die 2 "--minutes needs a number"; mins=$2; shift ;;
      -*) die 2 "unknown option: $1" ;;
      *) [ -z "$gid" ] || die 2 "only one rule id is allowed"; gid=$1 ;;
    esac
    shift
  done
  [ -n "$gid" ] || die 2 "grant needs a rule id"
  case $mins in ''|*[!0-9]*|?????*) die 2 "--minutes must be a whole number from 1 to 1440" ;; esac
  { [ "$mins" -ge 1 ] && [ "$mins" -le 1440 ]; } || die 2 "--minutes must be a whole number from 1 to 1440"
  valid_id "$gid" || die 1 "bad rule id: use a-z, 0-9 and -"
  ra_load "$root"
  [ -n "$RA_FILES" ] || die 1 "no approvals table found"
  [ "$RA_BROKEN" = 0 ] || die 1 "the approvals table has an error. Run: real-approvals.sh check"
  if [ "$gid" != default-write ]; then
    case $(rule_mode "$gid") in
      none) die 1 "unknown rule id: $gid" ;;
      deny) die 1 "a deny rule cannot be granted" ;;
      auto) die 1 "the rule is auto, there is nothing to grant" ;;
    esac
  fi
  gd=$(ra_grant_dir)
  [ ! -d "$gd/$gid" ] || die 1 "$gd/$gid is a folder"
  mkdir -p "$gd" && chmod 700 "$gd" || die 1 "cannot make the grants folder"
  gtmp=$gd/.tmp.$$
  if printf 'expires=%s\n' "$(( $(date +%s) + mins * 60 ))" > "$gtmp" && chmod 600 "$gtmp" && mv -f "$gtmp" "$gd/$gid"; then :; else rm -f "$gtmp"; die 1 "cannot write the grant"; fi
  printf 'granted %s for %s minutes\n' "$gid" "$mins"
}

do_revoke() {
  [ $# -eq 1 ] || die 2 "revoke needs one rule id"
  valid_id "$1" || die 1 "bad rule id: use a-z, 0-9 and -"
  gp=$(ra_grant_dir)/$1
  if [ -e "$gp" ] || [ -L "$gp" ]; then
    rm -f "$gp" || die 1 "cannot remove the grant"
    printf 'revoked %s\n' "$1"
  else
    printf 'no grant for %s\n' "$1"
  fi
}

do_export() {
  tfile=
  while [ $# -gt 0 ]; do
    case $1 in
      --tools) [ $# -ge 2 ] || die 2 "--tools needs a file"; tfile=$2; shift ;;
      *) die 2 "unknown option: $1" ;;
    esac
    shift
  done
  names=
  if [ -n "$tfile" ]; then
    if [ "$tfile" = - ]; then names=$(cat); else [ -r "$tfile" ] || die 1 "cannot read $tfile"; names=$(cat "$tfile"); fi
    names=$(printf '%s' "$names" | tr -d '\001-\003')
  fi
  ra_load "$root"
  rc=0
  out=$({
    printf '%s\n' "$RA_REC"
    if [ -n "$tfile" ]; then printf '\003'; printf '%s\n' "$names"; fi
  } | LC_ALL=C awk "$RA_AWK_COMMON
$RA_AWK_EXPORT") || rc=$?
  [ -n "$out" ] || die 1 "the export is empty. Check that awk works."
  if [ $rc -ne 0 ]; then printf '%s\n' "$out" | ra_clean >&2; exit 1; fi
  printf '%s\n' "$out" | ra_clean
}

cmd=${1:-}
[ -n "$cmd" ] || { usage >&2; exit 2; }
shift
case $cmd in
  -h|--help|help) usage ;;
  check) [ $# -eq 0 ] || die 2 "check takes no argument"; do_check ;;
  explain) do_explain "$@" ;;
  grant) do_grant "$@" ;;
  revoke) do_revoke "$@" ;;
  export-omp) do_export "$@" ;;
  *) die 2 "unknown command: $cmd. Run real-approvals.sh --help" ;;
esac
