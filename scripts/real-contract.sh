#!/bin/sh
# Manage the task contract of one worktree. POSIX sh. Needs git only. It changes only files under .real/ and docs/contracts/.
#
# Usage:
#   scripts/real-contract.sh new SLUG [--owner NAME]   Write a draft contract: .real/contract.md. It never overwrites a contract.
#   scripts/real-contract.sh approve                   Set Status: active. The user runs this. The guard asks before an agent can.
#   scripts/real-contract.sh add-scope GLOB            Add a glob to SCOPE. The user runs this.
#   scripts/real-contract.sh check PATH                Say if PATH is in scope, in DO NOT TOUCH or out of scope.
#   scripts/real-contract.sh show                      Print the task, the status and the lists.
#   scripts/real-contract.sh report                    Print the Claimed and Verified table and the verdict.
#   scripts/real-contract.sh done                      Set Status: done. It fails while a DONE WHEN item is not verified.
#   scripts/real-contract.sh reopen                    Set Status: active again.
#   scripts/real-contract.sh archive                   Copy the contract and the report to docs/contracts/YYYY-MM-DD-SLUG.md.
#
# The contract is local. Add `.real/` to .git/info/exclude or to the .gitignore of the repo. Do not commit it.
# Run the command in the worktree of the task, or use REAL_CONTRACT_ROOT to name the folder.

set -eu
set -f

here=$(cd "$(dirname "$0")" && pwd)
. "$here/../hooks/claude/contract-lib.sh"

die() { printf 'real-contract: %s\n' "$*" >&2; exit 1; }

root=${REAL_CONTRACT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}
root=$(cd "$root" && pwd -P)
f=$(rc_file "$root")
cmd=${1:-}
[ -n "$cmd" ] || { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
shift

need_contract() { [ -f "$f" ] || die "there is no contract in $root. Run: real-contract.sh new SLUG"; }

set_status() { # $1 = new status
  tmp=$f.tmp.$$
  awk -v s="$1" 'BEGIN { done = 0 } !done && /^Status:/ { print "Status: " s; done = 1; next } { print }' "$f" > "$tmp" && mv "$tmp" "$f"
}

warn_ignore() {
  if git -C "$root" rev-parse --git-dir >/dev/null 2>&1 && ! git -C "$root" check-ignore -q .real/contract.md 2>/dev/null; then
    printf 'real-contract: warning: .real/ is not ignored by git. Add it to .git/info/exclude or to .gitignore. Do not commit it.\n' >&2
  fi
}

case $cmd in
  new)
    slug=${1:-}
    [ -n "$slug" ] || die "give a slug: new SLUG"
    shift
    case $slug in *[!a-z0-9-]*|-*|'') die "the slug uses a-z, 0-9 and - only" ;; esac
    owner=${REAL_AGENT:-agent}
    if [ "${1:-}" = --owner ]; then owner=${2:-$owner}; fi
    [ ! -e "$f" ] || die "$f exists. Delete it yourself if you want a new contract."
    mkdir -p "$(rc_dir "$root")"
    cat > "$f" <<TEMPLATE
Task: $slug
Status: draft
Owner: $owner

## OBJECTIVE
<one sentence, one result>
## CONTEXT
<the files and sources to read first, with paths>
## SCOPE
<one path or glob for each bullet. Example: src/feature/**>
## DO NOT TOUCH
<paths and areas that are off limits. This section wins over SCOPE>
## DEPENDENCIES
<other tasks, services, keys, and who provides them. Write "none" if there are none>
## EXPECTED OUTPUT
<files, a PR or a report: the form of the result>
## DONE WHEN
<one measurable item for each bullet. Each item has a way to verify it>
TEMPLATE
    printf 'Wrote %s (Status: draft). Fill the sections. Then the user approves it with: real-contract.sh approve\n' "$f"
    warn_ignore
    ;;
  approve)
    need_contract
    [ "$(rc_status "$root")" = draft ] || die "only a draft can be approved. Status: $(rc_status "$root")"
    for s in OBJECTIVE CONTEXT SCOPE "DO NOT TOUCH" DEPENDENCIES "EXPECTED OUTPUT" "DONE WHEN"; do
      grep -q "^## $s[[:space:]]*\$" "$f" || die "the section '$s' is missing"
    done
    [ -n "$(rc_section "$f" SCOPE)" ] || die "SCOPE is empty. Write at least one path or glob as a bullet."
    [ -n "$(rc_section "$f" "DONE WHEN")" ] || die "DONE WHEN is empty. Write at least one measurable item as a bullet."
    set_status active
    # Remember where the work starts. The stop check also counts commits made after this point (an agent that commits has a clean worktree).
    git -C "$root" rev-parse HEAD > "$(rc_dir "$root")/base" 2>/dev/null || true
    printf 'Approved. Status: active. The guard now enforces SCOPE and DO NOT TOUCH.\n'
    ;;
  add-scope)
    need_contract
    glob=${1:-}
    [ -n "$glob" ] || die "give a glob: add-scope GLOB"
    [ "$(rc_status "$root")" != done ] || die "the contract is done. Use reopen first."
    if g=$(rc_first_match "$glob" "$(rc_section "$f" "DO NOT TOUCH")"); then die "$glob is inside DO NOT TOUCH ($g). DO NOT TOUCH wins. Edit the contract by hand if you mean it."; fi
    tmp=$f.tmp.$$
    awk -v g="$glob" '
      { print }
      /^##[[:space:]]+SCOPE[[:space:]]*$/ { print "- " g }' "$f" > "$tmp" && mv "$tmp" "$f"
    printf 'Added to SCOPE: %s\n' "$glob"
    ;;
  check)
    need_contract
    p=${1:-}
    [ -n "$p" ] || die "give a path: check PATH"
    abs=$(rc_abs "$p" "$(pwd)")
    rel=$(rc_rel "$abs" "$root") || { printf 'outside the worktree\n'; exit 1; }
    if g=$(rc_first_match "$rel" "$(rc_section "$f" "DO NOT TOUCH")"); then printf 'DO NOT TOUCH (%s)\n' "$g"; exit 1; fi
    if g=$(rc_first_match "$rel" "$(rc_section "$f" SCOPE)"); then printf 'in scope (%s)\n' "$g"; exit 0; fi
    printf 'outside SCOPE\n'; exit 1
    ;;
  show)
    need_contract
    printf 'Task: %s\nStatus: %s\nOwner: %s\nSCOPE:\n%s\nDO NOT TOUCH:\n%s\nDONE WHEN:\n%s\n' "$(rc_header "$f" Task)" "$(rc_status "$root")" "$(rc_header "$f" Owner)" \
      "$(rc_section "$f" SCOPE | sed 's/^/  /')" "$(rc_section "$f" "DO NOT TOUCH" | sed 's/^/  /')" "$(rc_section "$f" "DONE WHEN" | sed 's/^/  /')"
    ;;
  report)
    need_contract
    rc_report "$root"
    ;;
  done)
    need_contract
    [ "$(rc_status "$root")" = active ] || die "only an active contract can be closed. Status: $(rc_status "$root")"
    problems=$(rc_problems "$root")
    if [ -n "$problems" ]; then
      printf '%s\n' "$problems" >&2
      die "not done: a DONE WHEN item is not verified. Fix .real/claims.md first."
    fi
    set_status done
    printf 'Status: done. All DONE WHEN items are verified.\n'
    ;;
  reopen)
    need_contract
    set_status active
    printf 'Status: active\n'
    ;;
  archive)
    need_contract
    slug=$(rc_header "$f" Task)
    dest="$root/docs/contracts/$(date +%Y-%m-%d)-$slug.md"
    [ ! -e "$dest" ] || die "$dest exists."
    mkdir -p "$root/docs/contracts"
    { cat "$f"; printf '\n## REPORT\n\n'; rc_report "$root"; } > "$dest"
    printf 'Wrote %s\n' "$dest"
    ;;
  -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) die "unknown command: $cmd. Use --help." ;;
esac
