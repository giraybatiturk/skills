#!/bin/sh
# real-hooks-managed
# PreToolUse hook for the Bash tool. Works in Claude Code and in Codex.
# Deny (exit 2):  rm -rf on broad targets (/, ~, $HOME, .., ., *), git push --force to main,
#                 curl or wget piped into a shell.
# Ask (JSON):     rm -rf on other absolute, home or parent paths, git reset --hard, git clean -fd,
#                 git push --force to other branches, DROP TABLE, DROP DATABASE, DROP SCHEMA, TRUNCATE.
# Allowed:        rm -rf on node_modules, dist, build, coverage, .next, .turbo, .cache, __pycache__, .pytest_cache.
# Set REAL_ASK_MODE=deny for a client that does not support "ask" (Codex). Then every ask becomes a deny.
# Extra safe names: REAL_SAFE_DELETES="name1 name2".

. "$(dirname "$0")/lib.sh"
set -f

[ "$(rh_field tool_name)" = Bash ] || exit 0
cmd=$(rh_field command)
[ -n "$cmd" ] || exit 0

ask_reason=
note_ask() { [ -z "$ask_reason" ] && ask_reason=$1; }
deny() { rh_block "$1"; }

safe_names="node_modules dist build coverage .next .turbo .cache __pycache__ .pytest_cache ${REAL_SAFE_DELETES:-}"
is_safe_target() { # basename in the allowlist
  b=${1##*/}
  for s in $safe_names; do [ "$b" = "$s" ] && return 0; done
  return 1
}
is_broad() {
  case $1 in
    /|/\*|'~'|'~/'|'~/*'|\$HOME|\$HOME/|\$HOME/\*|\$\{HOME\}|\$\{HOME\}/|\$\{HOME\}/\*|..|../|../\*|../..|.|./|./\*|\*|.\*) return 0 ;;
  esac
  return 1
}

# rm with recursive and force flags
segs=$(rh_segments_unquoted "$cmd")
while IFS= read -r seg; do
  [ -z "$seg" ] && continue
  set -- $seg
  # skip env assignments, sudo and command
  while [ $# -gt 0 ]; do
    case $1 in
      sudo|command|[A-Za-z_]*=*) shift ;;
      *) break ;;
    esac
  done
  [ "${1:-}" = rm ] || continue
  shift
  rec=no; frc=no; targets=
  for w in "$@"; do
    case $w in
      --recursive) rec=yes ;;
      --force) frc=yes ;;
      --*) : ;;
      -*) case $w in *r*|*R*) rec=yes ;; esac; case $w in *f*) frc=yes ;; esac ;;
      *) targets="$targets $w" ;;
    esac
  done
  [ "$rec" = yes ] && [ "$frc" = yes ] || continue
  for t in $targets; do
    if is_broad "$t"; then deny "rm -rf on a broad target ($t) is blocked."; fi
  done
  for t in $targets; do
    is_safe_target "$t" && continue
    case $t in
      /*|'~'*|\$HOME*|\$\{HOME\}*|*..*) note_ask "rm -rf on $t is a delete outside a safe name. Ask the user first." ;;
    esac
  done
done <<SEGS
$segs
SEGS

# git commands
segs=$(rh_segments_noquoted "$cmd")
while IFS= read -r seg; do
  [ -z "$seg" ] && continue
  if printf '%s' "$seg" | grep -Eq "${RH_GIT}reset([[:space:]].*)?[[:space:]]--hard"; then
    note_ask "git reset --hard can destroy uncommitted work."
  fi
  if printf '%s' "$seg" | grep -Eq "${RH_GIT}clean[[:space:]]" \
     && printf '%s' "$seg" | grep -Eq '[[:space:]]-[a-zA-Z]*f|--force' \
     && printf '%s' "$seg" | grep -Eq '[[:space:]]-[a-zA-Z]*d|[[:space:]]-d'; then
    note_ask "git clean -fd deletes untracked files and folders."
  fi
  if printf '%s' "$seg" | grep -Eq "${RH_GIT}push([[:space:]]|\$)"; then
    forced=no
    printf '%s' "$seg" | grep -Eq '(^|[[:space:]])(--force|--force-with-lease(=[^[:space:]]+)?|-f|-[a-zA-Z]*f[a-zA-Z]*)([[:space:]]|$)' && forced=yes
    printf '%s' "$seg" | grep -Eq '[[:space:]]\+[A-Za-z0-9_./-]+' && forced=yes
    if [ "$forced" = yes ]; then
      to_main=no
      printf '%s' "$seg" | grep -Eq '(^|[[:space:]:+])(main|master)([[:space:]]|$)' && to_main=yes
      if [ "$to_main" = no ]; then
        # No branch named: the push goes to the current branch.
        if ! printf '%s' "$seg" | grep -Eq "push([[:space:]]+(-[^[:space:]]+|--[^[:space:]]+))*[[:space:]]+[^-[:space:]][^[:space:]]*[[:space:]]+[^-[:space:]]"; then
          rh_on_protected_branch && to_main=yes
        fi
      fi
      if [ "$to_main" = yes ]; then deny "git push --force to main is blocked."; fi
      note_ask "git push --force rewrites remote history."
    fi
  fi
done <<SEGS
$segs
SEGS

# SQL that drops data
if printf '%s' "$cmd" | grep -Eqi '(^|[^A-Za-z_])(drop[[:space:]]+(table|database|schema)|truncate[[:space:]]+(table[[:space:]]+)?[A-Za-z_"`])'; then
  note_ask "The command drops or truncates data (DROP, TRUNCATE)."
fi

# curl or wget piped into a shell
if printf '%s' "$cmd" | grep -Eq '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(env[[:space:]]+[^|]*)?(ba|z|da|k)?sh([[:space:]]|$)' \
   || printf '%s' "$cmd" | grep -Eq '(ba|z|da|k)?sh[[:space:]]+-c[[:space:]]+["'"'"']?\$\((curl|wget)'; then
  deny "Piping curl or wget into a shell is blocked. Download the file, read it, then run it."
fi

if [ -n "$ask_reason" ]; then
  if [ "${REAL_ASK_MODE:-ask}" = deny ]; then deny "$ask_reason"; fi
  reason=$(printf '%s' "$ask_reason" | rh_json_str)
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":%s}}\n' "$reason"
fi
exit 0
