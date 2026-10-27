#!/bin/sh
# real-mem.sh: search the memory service and print the matching memories, one for each line.
#
# Usage:
#   real-mem.sh search QUERY
#   real-mem.sh -h | --help
#
# Settings come from the environment only:
#   REAL_MEM_URL           base URL of the service, with no trailing slash (required)
#   REAL_MEM_TOKEN_FILE    file that holds the token (required). Only the owner can read it: mode 600 or 400.
#   REAL_MEM_USER          the user_id of the search (required)
#   REAL_MEM_LIMIT         number of memories to print. Default: 3
#   REAL_MEM_THRESHOLD     smallest score, a number (optional)
# The token goes to curl on standard input. It is never in an argument, an error or a log.
# The reply is read as {"results":[{"memory":"..."}]} or as a top-level array of the same objects.
# Without jq, a \u escape in a memory becomes "?". A newline inside a memory becomes a space.
# Exit codes: 0 ok (no output when nothing matches), 1 error (one line "real-mem: <reason>" on stderr), 2 bad usage.
# hooks/claude/real-context.sh can call it: REAL_CONTEXT_MEMORY_CMD="sh /path/to/scripts/real-mem.sh search".

set -f
umask 077
unset CDPATH

usage() { sed -n '2,/^$/p' "$0" | sed -e '$d' -e 's/^# \{0,1\}//'; }
case ${1:-} in
  -h|--help) usage; exit 0 ;;
esac
[ $# -eq 2 ] && [ "$1" = search ] && [ -n "$2" ] || { usage >&2; exit 2; }
query=$2

fail() { printf 'real-mem: %s\n' "$1" >&2; exit 1; }
have_jq() { [ -z "${REAL_NO_JQ:-}" ] && command -v jq >/dev/null 2>&1; }
# Plain text on standard input, a JSON string (with quotes) on standard output. lib.sh reads stdin when sourced, so this is a copy.
jstr() {
  tr -d '\000-\010\013\014\016-\037' | awk 'BEGIN { ORS = ""; printf "\"" }
    { gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t"); gsub(/\r/, ""); if (NR > 1) printf "\\n"; printf "%s", $0 }
    END { printf "\"" }'
}

[ -n "${REAL_MEM_URL:-}" ] || fail "REAL_MEM_URL is not set"
[ -n "${REAL_MEM_TOKEN_FILE:-}" ] || fail "REAL_MEM_TOKEN_FILE is not set"
[ -n "${REAL_MEM_USER:-}" ] || fail "REAL_MEM_USER is not set"
case $REAL_MEM_URL in http://*|https://*) ;; *) fail "REAL_MEM_URL must start with http:// or https://" ;; esac
limit=${REAL_MEM_LIMIT:-3}
case $limit in ''|*[!0-9]*|0*) fail "REAL_MEM_LIMIT is not a positive number" ;; esac
thr=${REAL_MEM_THRESHOLD:-}
if [ -n "$thr" ]; then
  case $thr in *[!0-9.]*|.*|*.|*.*.*) fail "REAL_MEM_THRESHOLD is not a number" ;; esac
fi

# The token. Refuse a missing file, a file that group or others can read, and a token with odd characters.
tf=$REAL_MEM_TOKEN_FILE
case $tf in -*) tf=./$tf ;; esac
[ -f "$tf" ] && [ -r "$tf" ] || fail "token file missing"
[ -z "$(find "$tf" -prune \( -perm -040 -o -perm -004 \) -print 2>/dev/null)" ] || fail "token file is readable by others"
token=
{ IFS= read -r token || [ -n "$token" ]; } < "$tf"
case $token in ''|*[!A-Za-z0-9._~+/=-]*) fail "token file does not hold a valid token" ;; esac

tmp=$(mktemp "${TMPDIR:-/tmp}/real-mem.XXXXXX") || fail "no temp file"
trap 'rm -f "$tmp"' EXIT
trap 'exit 1' INT TERM HUP

body="{\"query\":$(printf '%s' "$query" | jstr),\"user_id\":$(printf '%s' "$REAL_MEM_USER" | jstr),\"top_k\":$limit"
[ -n "$thr" ] && body="$body,\"threshold\":$thr"
body="$body}"

printf 'header = "Authorization: Bearer %s"\n' "$token" |
  curl -s -f -m 2 -K - -H 'Content-Type: application/json' --data-binary "$body" "${REAL_MEM_URL%/}/memories/search/" -o "$tmp" 2>/dev/null ||
  fail "memory service unavailable"

if have_jq; then
  out=$(jq -r '(.results? // .) | if type == "array" then .[] else empty end | .memory? // empty | strings | gsub("[\r\n]+"; " ") | select(length > 0)' "$tmp" 2>/dev/null) ||
    fail "the reply is not valid JSON"
else
  # Each "memory":"<JSON string>" pair, one memory for each line. A \uXXXX escape is not decoded.
  out=$(awk '{ s = s $0 "\n" }
    END {
      while (match(s, /"memory"[ \t\n]*:[ \t\n]*"/)) {
        s = substr(s, RSTART + RLENGTH); o = ""; i = 1; n = length(s)
        while (i <= n) {
          c = substr(s, i, 1)
          if (c == "\"") break
          if (c == "\\") {
            d = substr(s, i + 1, 1); i += 2
            if (d == "n" || d == "r" || d == "t") o = o " "
            else if (d == "u") { o = o "?"; i += 4 }
            else o = o d
          } else { o = o c; i++ }
        }
        s = substr(s, i + 1)
        if (o != "") print o
      }
    }' "$tmp")
fi
[ -z "$out" ] || printf '%s\n' "$out" | head -n "$limit"
exit 0
