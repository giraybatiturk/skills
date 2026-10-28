#!/bin/sh
# Find and run the task contract script (scripts/real-contract.sh of the skills repo). POSIX sh.
# The skill folder can be a symlink, a copy or a plugin folder, so this file looks for the script in this order:
#   1. $REAL_SKILLS_HOME/scripts/real-contract.sh
#   2. The repo that holds this skill folder (skills/product/real-plan/scripts is 4 levels below the repo root).
#   3. $CLAUDE_PLUGIN_ROOT/scripts/real-contract.sh
#   4. The folder in `git config real.skillsHome`. scripts/install-hooks.sh sets it in the repo that it installs into.
#   5. A real-contract.sh that is on PATH.
# Usage: real-contract.sh COMMAND [ARGUMENT ...]. The commands are the same as for scripts/real-contract.sh.
# Keep the file name: the contract guard asks the user before an agent runs "real-contract.sh approve".

set -eu

here=$(cd "$(dirname "$0")" && pwd -P)
me=$here/$(basename "$0")

found=
try() { # $1 = candidate path. Takes the first one that exists and is not this file.
  [ -z "$found" ] || return 0
  [ -f "$1" ] || return 0
  c=$(cd "$(dirname "$1")" 2>/dev/null && pwd -P)/$(basename "$1")
  [ "$c" != "$me" ] || return 0
  found=$c
}

[ -z "${REAL_SKILLS_HOME:-}" ] || try "$REAL_SKILLS_HOME/scripts/real-contract.sh"
try "$here/../../../../scripts/real-contract.sh"
[ -z "${CLAUDE_PLUGIN_ROOT:-}" ] || try "$CLAUDE_PLUGIN_ROOT/scripts/real-contract.sh"
home=$(git config --get real.skillsHome 2>/dev/null || true)
[ -z "$home" ] || try "$home/scripts/real-contract.sh"
oldifs=$IFS; IFS=:
for d in ${PATH:-}; do try "${d:-.}/real-contract.sh"; done
IFS=$oldifs

if [ -z "$found" ]; then
  cat >&2 <<'MSG'
real-contract: the script was not found.
Set REAL_SKILLS_HOME to your checkout of the skills repo, or run scripts/install-hooks.sh from that checkout for this repo.
Without the script, write .real/contract.md by hand. The format is in references/contract.md.
MSG
  exit 3
fi
exec sh "$found" "$@"
