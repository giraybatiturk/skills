#!/bin/sh
# real-hooks-managed
# SessionStart hook. It warns the user when the real git hooks are not active in the repo:
#   1. core.hooksPath is unset and the repo has no real hook in its hooks folder, or
#   2. core.hooksPath is set but it differs from the path that scripts/install-hooks.sh stored in git config real.hooksPath, or
#   3. core.hooksPath points to a folder that has no real pre-commit hook.
# It prints JSON with systemMessage (shown to the user) and additionalContext (shown to the agent).
# It stays silent outside a git repo and when all is fine. Turn off: REAL_SESSION_CHECK=0.
# It works in Claude Code and in Codex.

. "$(dirname "$0")/lib.sh"
set -f

[ "${REAL_SESSION_CHECK:-1}" = 0 ] && exit 0
cwd=$(rh_cwd)
git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1 || exit 0

has_marker() { [ -f "$1/pre-commit" ] && grep -q 'real-hooks-managed' "$1/pre-commit"; }

# --type=path expands a leading ~ the way git does when it runs the hooks.
hp=$(git -C "$cwd" config --type=path --get core.hooksPath 2>/dev/null || true)
expected=$(git -C "$cwd" config --get real.hooksPath 2>/dev/null || true)
problem=
if [ -z "$hp" ]; then
  gitpath=$(git -C "$cwd" rev-parse --git-path hooks 2>/dev/null)
  case $gitpath in /*) : ;; *) gitpath="$cwd/$gitpath" ;; esac
  has_marker "$gitpath" || problem="core.hooksPath is not set and the repo has no real pre-commit hook."
else
  if [ -n "$expected" ] && [ "$hp" != "$expected" ]; then
    problem="core.hooksPath changed. It is '$hp' but the installer set '$expected'."
  else
    case $hp in /*) dir=$hp ;; *) dir="$(git -C "$cwd" rev-parse --show-toplevel)/$hp" ;; esac
    has_marker "$dir" || problem="core.hooksPath is '$hp' but that folder has no real pre-commit hook."
  fi
fi
[ -n "$problem" ] || exit 0

msg="real: $problem Commits on main and untested pages are not blocked. Run scripts/install-hooks.sh <repo> to install the git hooks."
printf '{"systemMessage":%s,"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' \
  "$(printf '%s' "$msg" | rh_json_str)" "$(printf '%s' "$msg" | rh_json_str)"
exit 0
