#!/bin/sh
# real-ship.sh: commit, push and open the PR or MR in separate steps. It never merges.
#
# Usage:
#   real-ship.sh [commit|push] [-m MESSAGE] [--branch NAME] [--dry-run] [--no-suite-check]
#   real-ship.sh suite
#   real-ship.sh -h | --help
#
# No mode word: commit (when there are changes), push, then open the PR (GitHub) or the MR (GitLab).
# commit: commit only. push: commit (when there are changes) and push. Neither one calls gh or glab.
# suite: run the long test suite and write the marker. It makes no other change.
# -m MESSAGE sets the commit message. Without it the message is "Update 3 files: a, b, c and 2 more".
# --branch NAME runs "git switch -c NAME" first and carries the changes. Use it when you are on main.
# --dry-run runs every check, prints "would run: ..." lines and changes nothing.
# --no-suite-check turns a missing or stale suite marker into a warning.
#
# The script stages the changed files by name, never by pattern. It never forces a push, never skips
# a hook and never merges. It refuses on main, master, the default branch and the base branch.
# It refuses a secret-like file name and never stages .real/. The hooks of the repo run as usual.
#
# stdout: committed <sha7> "<subject>", pushed <branch>, then [PR #N](url) or [MR !N](url).
# Everything else goes to stderr. A refusal is one last line: real-ship: refused: <reason>. Next: <action>.
#
# Settings: env REAL_SHIP_<KEY>, then "real-ship.<key> = value" in .real-hooks, then git config
# real.hooks.real-ship.<key>. Keys: base (target branch), language (en only), suite (long test
# command, turns the marker check on) and host (github or gitlab, default: found from the origin URL).
#
# Exit codes: 0 ok (also dry-run and "PR already exists"), 1 refusal or failed step, 2 usage error.

set -f
unset CDPATH
here=$(cd "$(dirname "$0")" && pwd)

# Template words of the generated commit message.
w_update=Update w_file=file w_files=files w_and=and w_more=more

say() { printf '%s\n' "$*"; }
warn() { printf 'real-ship: warning: %s\n' "$*" >&2; }
usage() { printf 'real-ship: %s. Next: run real-ship.sh --help.\n' "$1" >&2; exit 2; }
refuse() { printf 'real-ship: refused: %s. Next: %s.\n' "$1" "$2" >&2; exit 1; }
retry='fix the problem above, then run /real-ship again'
q() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }
sha7() { git rev-parse HEAD | cut -c1-7; }

mode= msg= newbranch= dry=0 nosuite=0
while [ $# -gt 0 ]; do
  case $1 in
    -h|--help) awk 'NR > 1 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$0"; exit 0 ;;
    commit|push|suite) [ -z "$mode" ] || usage "unknown argument: $1"; mode=$1 ;;
    -m|--branch)
      [ $# -ge 2 ] && [ -n "$2" ] || usage "$1 needs a value"
      if [ "$1" = -m ]; then msg=$2; else newbranch=$2; fi
      shift ;;
    --dry-run) dry=1 ;;
    --no-suite-check) nosuite=1 ;;
    *) usage "unknown argument: $1" ;;
  esac
  shift
done
[ -n "$mode" ] || mode=full
if [ "$mode" = suite ] && { [ -n "$msg$newbranch" ] || [ "$dry" = 1 ] || [ "$nosuite" = 1 ]; }; then
  usage "suite takes no option"
fi

ta= tb= list= stg= co= ce=
trap 'rm -f "$ta" "$tb" "$list" "$stg" "$co" "$ce"' EXIT
trap 'exit 1' HUP INT TERM
mk() { mktemp "${TMPDIR:-/tmp}/real-ship.XXXXXX"; }
ta=$(mk) && tb=$(mk) && list=$(mk) && stg=$(mk) && co=$(mk) && ce=$(mk) || refuse "cannot make a temp file" "check the TMPDIR folder"

# 1. A git work tree with a commit. Work from its root.
root=$(git rev-parse --show-toplevel 2>/dev/null) || refuse "this folder is not in a git work tree" "run it inside a repo"
cd "$root" || refuse "cannot enter $root" "check the folder"
git rev-parse --verify -q HEAD >/dev/null 2>&1 || refuse "the repo has no commit" "make the first commit by hand"

cfg() { # cfg KEY: env REAL_SHIP_<KEY>, then .real-hooks, then git config
  case $1 in base) v=${REAL_SHIP_BASE:-} ;; language) v=${REAL_SHIP_LANGUAGE:-} ;; suite) v=${REAL_SHIP_SUITE:-} ;; host) v=${REAL_SHIP_HOST:-} ;; esac
  if [ -z "$v" ] && [ -f "$root/.real-hooks" ]; then
    v=$(sed -n "s/^[[:space:]]*real-ship\.$1[[:space:]]*=[[:space:]]*//p" "$root/.real-hooks" | head -n 1 | sed 's/[[:space:]]*$//')
  fi
  [ -n "$v" ] || v=$(git config --get "real.hooks.real-ship.$1" 2>/dev/null)
  printf '%s\n' "$v"
}

suite=$(cfg suite)
marker=$(git rev-parse --git-path real-suite-ok)
fingerprint() { # hash of the names and contents of the files. A commit does not change it.
  git -c core.quotePath=false ls-files -c -o --exclude-standard > "$ta" || return 1
  while IFS= read -r p; do
    case $p in .real/*) ;; *) [ -f "$p" ] && printf '%s\n' "$p" ;; esac
  done < "$ta" | LC_ALL=C sort -u > "$tb"
  git hash-object --stdin-paths < "$tb" > "$ta" || return 1
  paste "$tb" "$ta" | git hash-object --stdin
}

if [ "$mode" = suite ]; then
  [ -n "$suite" ] || refuse "no long suite is set" "set real-ship.suite in .real-hooks"
  fp=$(fingerprint) && [ -n "$fp" ] || refuse "cannot read the state of the files" "$retry"
  sh -c "$suite" >&2; rc=$?
  [ "$rc" -eq 0 ] || refuse "the long test suite failed (exit $rc)" "fix it, then run real-ship.sh suite again"
  printf '%s\n' "$fp" > "$marker" || refuse "cannot write the suite marker" "check the .git folder"
  say "suite passed $(printf '%s' "$fp" | cut -c1-7)"
  exit 0
fi

# 2. The branch. A protected branch is main, master, the default branch of origin and the base branch.
cur=$(git symbolic-ref --short -q HEAD) || refuse "HEAD is detached" "switch to a branch, then run /real-ship again"
dflt=$(git symbolic-ref --short -q refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
base=$(cfg base)
if [ -z "$base" ]; then
  if [ -n "$dflt" ]; then base=$dflt
  elif git show-ref --verify -q refs/remotes/origin/main; then base=main
  elif git show-ref --verify -q refs/remotes/origin/master; then base=master
  fi
fi
protected() {
  case $1 in main|master) return 0 ;; esac
  [ -n "$dflt" ] && [ "$1" = "$dflt" ] && return 0
  [ -n "$base" ] && [ "$1" = "$base" ]
}
if [ -n "$newbranch" ]; then
  chk=$(git check-ref-format --branch "$newbranch" 2>/dev/null) && [ "$chk" = "$newbranch" ] || refuse "'$newbranch' is not a valid branch name" "choose another name for --branch"
  protected "$newbranch" && refuse "'$newbranch' is a protected branch" "choose another name for --branch"
  git show-ref --verify -q "refs/heads/$newbranch" && refuse "the branch '$newbranch' already exists" "choose another name for --branch"
  branch=$newbranch
else
  protected "$cur" && refuse "the branch '$cur' is protected" "run /real-ship --branch feat/<short-name>"
  branch=$cur
fi
# A name that starts with + would be a force refspec for git push.
case $branch in +*) refuse "the branch name '$branch' starts with +" "rename the branch" ;; esac

# 3. The base. Full mode needs one.
bref=
if [ -n "$base" ]; then
  if git show-ref --verify -q "refs/remotes/origin/$base"; then bref=origin/$base
  elif git show-ref --verify -q "refs/heads/$base"; then bref=$base
  fi
fi
[ "$mode" != full ] || [ -n "$base" ] || refuse "no base branch is known" "set real-ship.base in .real-hooks"

# 4. The remote. 5. The host and its CLI.
if [ "$mode" != commit ]; then
  url=$(git remote get-url origin 2>/dev/null) || refuse "there is no remote named origin" "run git remote add origin <url>"
fi
if [ "$mode" = full ]; then
  host=$(cfg host)
  if [ -z "$host" ]; then
    # Read the host part only for a real remote URL: scheme://[user@]host[:port]/path or scp-like [user@]host:path.
    # A local path (absolute, relative or file:///...) has no host part, so the whole URL is matched.
    case $url in
      *://*) h=${url#*://}; h=${h%%/*}; h=${h##*@}; h=${h%%:*} ;;
      *) h=${url%%/*}; case $h in *:*) h=${h##*@}; h=${h%%:*} ;; *) h=$url ;; esac ;;
    esac
    [ -n "$h" ] || h=$url
    case $h in *gitlab*) host=gitlab ;; *github*) host=github ;; esac
  fi
  case $host in
    github) cli=gh sub=pr kind=PR ;;
    gitlab) cli=glab sub=mr kind=MR ;;
    *) refuse "the host is not github or gitlab" "set real-ship.host = github or gitlab in .real-hooks" ;;
  esac
  command -v "$cli" >/dev/null 2>&1 || refuse "$cli not found" "install $cli, or run /real-ship push and open the $kind yourself"
fi

# 6. The change list: tracked changes (also deletions), staged adds and changes, and untracked files that are not ignored.
# A staged file that is gone from the work tree is only in the staged list. The commit would take it from the index.
git -c core.quotePath=false diff --name-only --no-renames HEAD > "$ta" || refuse "git cannot list the changes" "$retry"
git -c core.quotePath=false diff --cached --name-only --no-renames --diff-filter=d HEAD > "$stg" || refuse "git cannot list the staged files" "$retry"
cat "$stg" >> "$ta"
git -c core.quotePath=false ls-files -o --exclude-standard >> "$ta" || refuse "git cannot list the files" "$retry"
LC_ALL=C sort -u "$ta" > "$tb"
git -c core.quotePath=false diff --cached --name-only --no-renames | grep -q '^\.real/' && refuse "a file under .real/ is staged" "run git restore --staged .real"
while IFS= read -r p; do
  case $p in
    ''|.real/*) continue ;;
    \"*) refuse "the file name '$p' has a special character" "rename the file" ;;
  esac
  printf '%s\n' "$p"
done < "$tb" > "$list"
n=$(wc -l < "$list" | tr -d ' ')
if [ "$n" -eq 0 ]; then
  [ "$mode" != commit ] || refuse "nothing to commit" "change a file first"
  ahead=
  [ -z "$bref" ] || ahead=$(git rev-list --count "$bref..HEAD" 2>/dev/null)
  [ "$ahead" != 0 ] || refuse "nothing to commit or push" "change a file first"
fi

# 7. Secret names. The rules match hooks/claude/protect-secrets.sh, but the match ignores case.
# A path counts when it is in the work tree or staged. A plain deletion is fine.
is_secret() {
  b=$(printf '%s' "${1##*/}" | tr 'A-Z' 'a-z')
  case $b in
    .env.example|.env.sample|.env.template|.env.dist|*.pub) return 1 ;;
    .env|.env.*|*.pem|*.key|*.p12|*.pfx|id_rsa*|id_ed25519*|id_ecdsa*|id_dsa*|credentials|credentials.json) return 0 ;;
  esac
  return 1
}
while IFS= read -r p; do
  if { [ -e "$p" ] || [ -L "$p" ] || grep -qxF -e "$p" "$stg"; } && is_secret "$p"; then
    refuse "secret-like file '$p'" "add it to .gitignore or remove it, then run /real-ship again"
  fi
done < "$list"

# 8. The suite marker (opt-in).
if [ "$mode" != commit ] && [ -n "$suite" ]; then
  fp=$(fingerprint)
  if ! { [ -n "$fp" ] && [ "$(cat "$marker" 2>/dev/null)" = "$fp" ]; }; then
    [ "$nosuite" = 1 ] || refuse "the long test suite has not passed on this state" "run real-ship.sh suite, then run /real-ship again"
    warn "the long test suite has not passed on this state. --no-suite-check is set, so the ship continues."
  fi
fi

# The message. The subject is its first line.
if [ "$n" -gt 0 ]; then
  if [ -z "$msg" ]; then
    lang=$(cfg language)
    case $lang in ''|en) ;; *) warn "no message template for language '$lang'. The message is in English. Use -m for another language." ;; esac
    noun=$w_files
    [ "$n" -ne 1 ] || noun=$w_file
    names=$(awk -F/ 'NR <= 3 { printf "%s%s", (NR > 1 ? ", " : ""), $NF }' "$list")
    msg="$w_update $n $noun: $names"
    [ "$n" -le 3 ] || msg="$msg $w_and $((n - 3)) $w_more"
  fi
  subj=$(printf '%s\n' "$msg" | head -n 1)
else
  subj=$(git log -1 --format=%s)
fi

# 9. Dry run.
if [ "$dry" = 1 ]; then
  [ -z "$newbranch" ] || say "would run: git switch -c $newbranch"
  if [ "$n" -gt 0 ]; then
    say "would run: git --literal-pathspecs add --pathspec-from-file=FILE"
    say "would run: git commit -m $(q "$msg")"
  fi
  [ "$mode" = commit ] || say "would run: git push -u origin refs/heads/$branch:refs/heads/$branch"
  if [ "$mode" = full ]; then
    if [ "$host" = github ]; then
      say "would run: gh pr create --base $base --head $branch --title $(q "$subj") --body '<commit list>'"
    else
      say "would run: glab mr create --target-branch $base --source-branch $branch --title $(q "$subj") --description '<commit list>' --yes"
    fi
  fi
  exit 0
fi

# Actions. Each step has its own command and its own error.
if [ -n "$newbranch" ]; then
  git switch -c "$newbranch" >&2 || refuse "git cannot create the branch '$newbranch'" "$retry"
fi
if [ "$n" -gt 0 ]; then
  git --literal-pathspecs add --pathspec-from-file="$list" >&2 || refuse "git cannot stage the files" "$retry"
  git commit -m "$msg" >&2 || refuse "the commit failed" "$retry"
  say "committed $(sha7) \"$subj\""
else
  say "nothing to commit, HEAD $(sha7) \"$subj\""
fi
[ "$mode" != commit ] || exit 0

# A full refspec, so a remote.origin.push setting cannot send the branch to another name.
git push -u origin "refs/heads/$branch:refs/heads/$branch" >&2 || refuse "the push failed. The commit $(sha7) stays on $branch" "fix the cause above, then run the same /real-ship command again"
say "pushed $branch"
[ "$mode" != push ] || exit 0

# The PR or MR. The body is the commit list, then the contract report when there is one.
nl='
'
log=$(git log --no-merges --reverse --format='- %s' "${bref:-HEAD}..HEAD" 2>/dev/null)
[ -n "$log" ] || log="- $(git log -1 --format=%s)"
body="Commits:$nl$log"
if [ -f "$root/.real/contract.md" ] && [ -f "$here/real-contract.sh" ]; then
  if rep=$(REAL_CONTRACT_ROOT=$root sh "$here/real-contract.sh" report); then
    body=$body$nl$nl$rep
  else
    warn "real-contract.sh report failed. The body has the commit list only."
  fi
fi
title=$(git log -1 --format=%s)
link() { # link URL: N is the digits after the last slash
  num=${1##*/}
  case $num in ''|*[!0-9]*) num= ;; esac
  if [ "$host" = github ]; then say "[PR${num:+ #$num}]($1)"; else say "[MR${num:+ !$num}]($1)"; fi
}
if [ "$host" = github ]; then
  gh pr create --base "$base" --head "$branch" --title "$title" --body "$body" > "$co" 2> "$ce"
else
  glab mr create --target-branch "$base" --source-branch "$branch" --title "$title" --description "$body" --yes > "$co" 2> "$ce"
fi
rc=$?
if [ "$rc" -eq 0 ]; then
  cat "$ce" >&2
  url=$(sed -nE 's#.*(https?://[^[:space:]]+).*#\1#p' "$co" | tail -n 1)
  [ -n "$url" ] || refuse "$cli gave no link" "run $cli $sub view $branch"
  link "$url"
  exit 0
fi
# A failed create can mean that the PR or MR exists. Only then is the link in the output a result.
cat "$co" "$ce" >&2
url=
if cat "$co" "$ce" | grep -qi 'already exists'; then
  url=$(cat "$co" "$ce" | sed -nE 's#.*(https?://[^[:space:]]*/(pull|merge_requests)/[0-9]+)([^0-9/A-Za-z_-].*)?$#\1#p' | head -n 1)
fi
if [ -n "$url" ]; then link "$url"; exit 0; fi
refuse "the $kind was not created. The branch $branch is pushed" "read the message above, then run /real-ship again"
