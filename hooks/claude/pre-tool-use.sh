#!/bin/sh
# real-hooks-managed
# PreToolUse hook for the Bash tool. Works in Claude Code and in Codex.
# It blocks these commands:
#   1. git commit and git push in one command (joined with &&, ;, || or a single &).
#   2. git commit on main, master or the default branch. Bypass: set REAL_ALLOW_MAIN=1 before you start the agent.
#   3. git commit or git push with --no-verify (and git commit -n), or with core.hooksPath set on the command line.
#   4. A command that sets a REAL_ALLOW_* bypass variable. Only the user can set the bypass in the environment.
# Exit code 2 blocks the tool call. The reason goes to stderr.

. "$(dirname "$0")/lib.sh"
set -f

[ "$(rh_field tool_name)" = Bash ] || exit 0
cmd=$(rh_field command)
[ -n "$cmd" ] || exit 0

commit=no
push=no
segs=$(rh_segments_noquoted "$cmd")
while IFS= read -r seg; do
  [ -z "$seg" ] && continue
  if printf '%s' "$seg" | grep -Eq "${RH_GIT}commit([[:space:]]|\$)"; then
    commit=yes
    if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])(--no-verify|-n)([[:space:]]|$)'; then
      rh_block "git commit --no-verify is blocked. The hooks must run. Fix the problem that the hook reports."
    fi
  fi
  if printf '%s' "$seg" | grep -Eq "${RH_GIT}push([[:space:]]|\$)"; then
    push=yes
    if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])--no-verify([[:space:]]|$)'; then
      rh_block "git push --no-verify is blocked. The hooks must run. Fix the problem that the hook reports."
    fi
  fi
  if printf '%s' "$seg" | grep -Eq "${RH_GIT}(commit|push)" && printf '%s' "$seg" | grep -q 'core\.hooksPath'; then
    rh_block "Setting core.hooksPath on a git commit or git push command is blocked."
  fi
done <<SEGS
$segs
SEGS

if [ "$commit" = yes ] || [ "$push" = yes ]; then
  if printf '%s' "$segs" | grep -Eq 'REAL_ALLOW_[A-Z_]+='; then
    rh_block "Do not set a REAL_ALLOW_* bypass variable in the command. Only the user can set it, before the agent starts."
  fi
fi

if [ "$commit" = yes ] && [ "$push" = yes ]; then
  rh_block "Do not commit and push in one command. Run git commit first. Then run git push as a separate command."
fi

if [ "$commit" = yes ] && [ "${REAL_ALLOW_MAIN:-}" != 1 ] && rh_on_protected_branch; then
  rh_block "git commit on the main or default branch is blocked. Create a branch first: git switch -c <type>/<name>."
fi
exit 0
