#!/bin/sh
# real-hooks-managed
# PreToolUse hook. Matcher for Claude Code: Read|Edit|MultiEdit|Write|NotebookEdit|Grep|Glob|Bash
# It blocks access to secret files: .env and .env.* (but not .env.example, .env.sample, .env.template, .env.dist),
# *.pem, *.p12, *.pfx, id_rsa, id_ed25519, id_ecdsa, id_dsa (but not *.pub), credentials, credentials.json.
# For a file tool it checks the path fields of the input.
# For Bash and for apply_patch it checks every word of the command. This catches "TZ=x cat .env" and "grep KEY .env".
# Extra allowed names: REAL_SECRET_ALLOW="name1 name2". Exit code 2 blocks the call.
# Limit: a glob such as ".e*" or a name that a program builds at run time is not caught.

. "$(dirname "$0")/lib.sh"
set -f

tool=$(rh_field tool_name)

is_secret() { # $1 = path or word. Succeeds when the basename is a secret file name.
  b=${1##*/}
  for a in ${REAL_SECRET_ALLOW:-}; do [ "$b" = "$a" ] && return 1; done
  case $b in
    .env.example|.env.sample|.env.template|.env.dist) return 1 ;;
    *.pub) return 1 ;;
    .env|.env.*|.env\*|*.pem|*.p12|*.pfx|id_rsa|id_ed25519|id_ecdsa|id_dsa|credentials|credentials.json) return 0 ;;
  esac
  return 1
}

deny_path() {
  rh_block "Access to the secret file '$1' is blocked. Ask the user to give the needed value. Use .env.example for the names of the variables."
}

case $tool in
  Bash|apply_patch)
    cmd=$(rh_field command)
    [ -n "$cmd" ] || exit 0
    words=$(printf '%s' "$cmd" | tr ';&|<>()"'"'"'`=,:' '            ')
    for w in $words; do
      if is_secret "$w"; then deny_path "$w"; fi
    done
    ;;
  Read|Edit|MultiEdit|Write|NotebookEdit|Grep|Glob|mcp__*)
    for key in file_path notebook_path path glob; do
      p=$(rh_field "$key")
      [ -n "$p" ] || continue
      if is_secret "$p"; then deny_path "$p"; fi
    done
    ;;
esac
exit 0
