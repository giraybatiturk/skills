#!/bin/sh
# real-hooks-managed
# PreToolUse hook for the task contract. Matcher for Claude Code: Edit|MultiEdit|Write|NotebookEdit|Bash.
# For Codex: apply_patch|Bash.
# The contract is the file .real/contract.md. It is local: it is not committed. See hooks/README.md.
#
# With an active contract (Status: active), a write is stopped when the path is
#   1. inside DO NOT TOUCH (this rule wins over SCOPE),
#   2. outside SCOPE, or outside the worktree.
# The contract file and .real/evidence.jsonl are protected too. An agent cannot change an active contract.
# The user changes SCOPE with scripts/real-contract.sh add-scope.
# Without an active contract, work on more than 3 files needs one. The edit of a 4th changed file is stopped.
# Setting contract.required: auto (default), always or off.
#
# Action: "ask" in Claude Code. "block" (exit 2) when REAL_ASK_MODE=deny or contract.mode = block (Codex, omp).
# Bash: a best-effort check of the targets of >, >>, tee, sed -i, mv, cp, rm, touch and truncate.
# A command that builds its target at run time is not caught. This hook is a guardrail, not a boundary.
# Bypass: the user sets REAL_ALLOW_SCOPE=1 before the agent starts. Turn off: REAL_CONTRACT_GUARD=0.

. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/contract-lib.sh"
set -f

[ "${REAL_CONTRACT_GUARD:-1}" = 0 ] && exit 0
[ "${REAL_ALLOW_SCOPE:-}" = 1 ] && exit 0

tool=$(rh_field tool_name)
cwd=$(rh_cwd)
root=$(rh_root)
root=$(cd "$root" 2>/dev/null && pwd -P) || exit 0
cfile=$(rc_file "$root")
status=$(rc_status "$root")
cli=$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)/scripts/real-contract.sh

decide() { # $1 = reason. Ask the user, or block, as the client supports.
  if [ "${REAL_ASK_MODE:-}" = deny ] || [ "$(rh_cfg contract.mode)" = block ]; then
    rh_block "$1"
  fi
  reason=$(printf 'real: %s' "$1" | rh_json_str)
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":%s}}\n' "$reason"
  exit 0
}

# ---------- the targets of the tool call ----------

bash_targets() { # $1 = command. Prints the write targets, one for each line.
  segs=$(rh_segments_unquoted "$1")
  while IFS= read -r seg; do
    [ -n "$seg" ] || continue
    printf '%s\n' "$seg" | grep -oE '[0-9]*>>?[[:space:]]*[^[:space:]<>&|;()]+' | sed -E 's/^[0-9]*>>?[[:space:]]*//'
    seg=$(printf '%s\n' "$seg" | sed -E -e 's/[0-9]*<[<-]?[[:space:]]*[^[:space:]]*//g' -e 's/[0-9]*>>?[[:space:]]*[^[:space:]<>&|;()]+//g')
    set -- $seg
    while [ $# -gt 0 ]; do
      case $1 in
        sudo|command|env|nohup|time|nice) shift ;;
        [A-Za-z_]*=*) shift ;;
        *) break ;;
      esac
    done
    [ $# -gt 0 ] || continue
    c=$(basename "$1")
    shift
    case $c in
      tee|rm|touch|truncate|unlink|mv)
        for a in "$@"; do case $a in -*) : ;; *) printf '%s\n' "$a" ;; esac; done ;;
      cp|install)
        last=; for a in "$@"; do case $a in -*) : ;; *) last=$a ;; esac; done
        [ -n "$last" ] && printf '%s\n' "$last" ;;
      sed|perl)
        inplace=no; last=
        for a in "$@"; do
          case $a in -i*|--in-place*) inplace=yes ;; -*) : ;; *) last=$a ;; esac
        done
        [ "$inplace" = yes ] && [ -n "$last" ] && printf '%s\n' "$last" ;;
      dd)
        for a in "$@"; do case $a in of=*) printf '%s\n' "${a#of=}" ;; esac; done ;;
    esac
  done <<RC_SEGS
$segs
RC_SEGS
}

targets=
case $tool in
  Edit|MultiEdit|Write) targets=$(rh_field file_path) ;;
  NotebookEdit) targets=$(rh_field notebook_path); [ -n "$targets" ] || targets=$(rh_field file_path) ;;
  apply_patch)
    targets=$(rh_field command | sed -nE 's/^\*\*\* (Update|Add|Delete) File: (.*)$/\2/p; s/^\*\*\* Move to: (.*)$/\1/p') ;;
  Bash)
    cmd=$(rh_field command)
    [ -n "$cmd" ] || exit 0
    if printf '%s' "$cmd" | grep -Eq 'REAL_ALLOW_SCOPE='; then
      rh_block "Do not set REAL_ALLOW_SCOPE in a command. Only the user can set the bypass, before the agent starts."
    fi
    if printf '%s' "$cmd" | grep -Eq 'real-contract(\.sh)?[[:space:]]+(approve|add-scope|done|reopen)([[:space:]]|$)'; then
      decide "This command changes the status or the scope of the contract. Only the user can approve it. Ask the user, or ask the user to run it in a terminal."
    fi
    targets=$(bash_targets "$cmd") ;;
  *) exit 0 ;;
esac
[ -n "$targets" ] || exit 0

# ---------- one target ----------

changed_files() { # Prints the changed paths of the worktree, without .real/ and docs/contracts/.
  git -C "$root" status --porcelain -uall 2>/dev/null | sed -e 's/^...//' -e 's/.* -> //' -e 's/^"//' -e 's/"$//' | grep -v -e '^\.real/' -e '^docs/contracts/'
}

check_target() { # $1 = path as the tool gave it
  t=$1
  case $t in *'$'*|'~'*) return 0 ;; esac # Cannot resolve a variable. The guard does not guess.
  abs=$(rc_abs "$t" "$cwd")
  if ! rel=$(rc_rel "$abs" "$root"); then
    rc_is_temp "$abs" && return 0
    [ "$status" = active ] && decide "$t is outside the worktree. The active contract '$(rc_header "$cfile" Task)' covers the worktree only."
    return 0
  fi
  case $rel in
    .real/contract.md)
      if [ "$status" = active ] || [ "$status" = done ]; then
        decide "The contract is $status. An agent cannot change it. The user changes SCOPE with: $cli add-scope <glob>"
      fi
      return 0 ;;
    .real/evidence.jsonl)
      decide "The evidence log is written by a hook. An agent cannot edit it." ;;
    .real/*|docs/contracts/*) return 0 ;;
  esac
  if [ "$status" = active ]; then
    task=$(rc_header "$cfile" Task)
    dnt=$(rc_section "$cfile" "DO NOT TOUCH")
    if g=$(rc_first_match "$rel" "$dnt"); then
      decide "$rel is inside DO NOT TOUCH ($g) of the contract '$task'. This rule wins over SCOPE. Ask the user."
    fi
    scope=$(rc_section "$cfile" SCOPE)
    if [ -z "$scope" ]; then decide "SCOPE of the contract '$task' is empty, so $rel is outside SCOPE. Ask the user."; fi
    if ! rc_first_match "$rel" "$scope" >/dev/null; then
      decide "$rel is outside SCOPE of the contract '$task'. To add it, the user runs: $cli add-scope $rel"
    fi
    return 0
  fi
  # No active contract.
  req=$(rh_cfg contract.required)
  case $req in off) return 0 ;; esac
  if [ "$req" = always ]; then
    decide "There is no active contract (status: ${status:-none}). Write one with the real-plan contract mode, and ask the user to approve it."
  fi
  list=$(changed_files)
  if [ -n "$list" ] && printf '%s\n' "$list" | grep -qxF -- "$rel"; then return 0; fi
  count=0
  [ -n "$list" ] && count=$(printf '%s\n' "$list" | wc -l | tr -d ' ')
  if [ "$count" -ge 3 ]; then
    decide "This would be the 4th changed file ($rel). Work on more than 3 files needs a contract. Status: ${status:-none}. Write one with the real-plan contract mode, and ask the user to approve it."
  fi
  return 0
}

while IFS= read -r t; do
  [ -n "$t" ] || continue
  check_target "$t"
done <<RC_TARGETS
$targets
RC_TARGETS
exit 0
