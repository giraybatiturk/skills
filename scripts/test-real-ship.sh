#!/bin/sh
# Test scripts/real-ship.sh in temporary repos. POSIX sh. Needs git.
# The test uses a temporary HOME and git config, a bare remote in a temporary folder and stubs for gh and glab.
# It never calls the real gh or glab, it never reaches the network and it starts no server.
# A git wrapper in PATH logs every call of the script under test. The last section scans the logs.
# Usage: sh scripts/test-real-ship.sh   (or: bash --posix scripts/test-real-ship.sh)
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
RS=$ROOT/scripts/real-ship.sh
REALGIT=$(command -v git)
SH=$(command -v sh)

TMP=$(mktemp -d "${TMPDIR:-/tmp}/real-ship-test.XXXXXX") || exit 1
TMP=$(cd "$TMP" && pwd -P)
trap 'cd /; rm -rf "$TMP"' EXIT
trap 'exit 1' INT TERM

# Isolated environment
mkdir -p "$TMP/home" "$TMP/config" "$TMP/tmp" "$TMP/stub" "$TMP/work"
export HOME="$TMP/home"
export XDG_CONFIG_HOME="$TMP/config"
export TMPDIR="$TMP/tmp"
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL="$HOME/.gitconfig"
printf '[user]\n\tname = test\n\temail = test\n[init]\n\tdefaultBranch = main\n' > "$HOME/.gitconfig"
for v in $(env | sed -n 's/^\(REAL_[A-Za-z_]*\)=.*/\1/p'); do unset "$v"; done
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_PREFIX
GITLOG=$TMP/git.log
: > "$GITLOG"

# The git wrapper logs its arguments and runs the real git.
cat > "$TMP/stub/git" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$GITLOG"
exec "$REALGIT" "\$@"
EOF
# A stub of gh or glab. The mode file selects ok, exists, fail or nourl. The body goes to NAME.body.
mkcli() { # mkcli NAME OK_URL EXISTS_URL
  cat > "$TMP/stub/$1" <<EOF
#!/bin/sh
d="$TMP"
log=; prev=
for a in "\$@"; do
  case \$prev in --body|--description) printf '%s\n' "\$a" > "\$d/$1.body"; a='<body>' ;; esac
  log="\$log \$a"; prev=\$a
done
printf '%s\n' "\${log# }" >> "\$d/$1.log"
printf '%s\n' "\${log# }" >> "\$d/all-cli.log"
case \$(cat "\$d/$1.mode") in
  ok) echo 'Creating the request' >&2; echo '$2' ;;
  exists) printf 'a request already exists:\n%s\n' '$3' >&2; exit 1 ;;
  fail) echo 'the server said no' >&2; exit 1 ;;
  nourl) echo 'created' ;;
  tty) printf '!3 title (b)\n %s\n' '$2' ;;
  authfail) printf 'error: authentication failed. See %s for the old one\n' '$3' >&2; exit 1 ;;
esac
EOF
}
mkcli gh https://github.com/o/r/pull/7 https://github.com/o/r/pull/12
mkcli glab https://gitlab.com/o/r/-/merge_requests/3 https://gitlab.com/o/r/-/merge_requests/12
chmod +x "$TMP/stub/git" "$TMP/stub/gh" "$TMP/stub/glab"
: > "$TMP/all-cli.log"
PATH=$TMP/stub:$PATH
export PATH

# A PATH that has the git wrapper and the plain tools, but no gh and no glab.
mkdir -p "$TMP/bin-nocli"
cp "$TMP/stub/git" "$TMP/bin-nocli/git"
for t in sed awk tr grep sort paste wc head tail cut mktemp rm cat dirname sh; do
  p=$(command -v "$t") && ln -s "$p" "$TMP/bin-nocli/$t"
done

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; [ -n "${2:-}" ] && printf '      %s\n' "$2"; return 0; }
section() { printf '== %s\n' "$1"; }
eq() { if [ "$2" = "$3" ]; then ok; else bad "$1" "expected '$3', got '$2'"; fi; }
has() { case $2 in *"$3"*) ok ;; *) bad "$1" "missing text: $3 | in: $2" ;; esac; }
hasnt() { case $2 in *"$3"*) bad "$1" "unexpected text: $3 | in: $2" ;; *) ok ;; esac; }
rx() { if printf '%s\n' "$2" | grep -Eq -e "$3"; then ok; else bad "$1" "no match for $3 in: $2"; fi; }
nrx() { printf '%s\n' "$2" | grep -Eq -e "$3"; case $? in 1) ok ;; 0) bad "$1" "unexpected match for $3 in: $2" ;; *) bad "$1" "bad pattern: $3" ;; esac; }
die() { printf 'test setup failed: %s\n' "$1" >&2; exit 1; }

g() { "$REALGIT" "$@"; }
SCRIPT=$RS
rs() { if [ -n "${BASH_VERSION:-}" ]; then "$BASH" --posix "$SCRIPT" "$@"; else "$SH" "$SCRIPT" "$@"; fi; }
RC=0; OUT=; ERR=
run() { # run ARGS: runs real-ship.sh in the current folder. Sets RC, OUT and ERR.
  RC=0
  OUT=$(rs "$@" 2>"$TMP/err") || RC=$?
  ERR=$(cat "$TMP/err")
}
runp() { # runp BINDIR ARGS: the same with PATH limited to BINDIR
  b=$1; shift; RC=0
  OUT=$(PATH=$b; rs "$@" 2>"$TMP/err") || RC=$?
  ERR=$(cat "$TMP/err")
}

lines() { printf '%s\n' "$1" | wc -l | tr -d ' '; }
line() { printf '%s\n' "$1" | sed -n "${2}p"; }
last() { printf '%s\n' "$1" | tail -n 1; }
calls() { cat "$TMP/gh.log" "$TMP/glab.log" | wc -l | tr -d ' '; }
glines() { wc -l < "$GITLOG" | tr -d ' '; }
newgit() { tail -n +$(($1 + 1)) "$GITLOG"; } # git calls after line number $1
snap() { printf '%s %s %s %s\n' "$(g rev-parse HEAD 2>/dev/null)" "$(g symbolic-ref -q HEAD)" "$(g ls-files -s | cksum)" "$(g -C "$R" for-each-ref | cksum)"; }
before() { S0=$(snap); }
still() { eq "$1: HEAD, branch, index and remote are unchanged" "$(snap)" "$S0"; eq "$1: gh and glab are not called" "$(calls)" 0; }
refused() { # refused NAME TEXT: exit 1, empty stdout, the last stderr line is one refusal that holds TEXT
  eq "$1: exit 1" "$RC" 1
  eq "$1: stdout is empty" "$OUT" ""
  L=$(last "$ERR")
  rx "$1: refusal format" "$L" '^real-ship: refused: .+\. Next: .+\.$'
  has "$1: reason" "$L" "$2"
}
refused_clean() { refused "$1" "$2"; still "$1"; }

mkrepo() { # mkrepo NAME [KIND]: one commit on main, a bare remote in a folder named KIND. Sets R and W, enters W.
  k=${2:-github}; R=$TMP/$k/$1.git; W=$TMP/work/$1
  mkdir -p "$TMP/$k"
  g init -q --bare "$R" 2>/dev/null && g -C "$R" symbolic-ref HEAD refs/heads/main || die "bare remote $1"
  g init -q "$W" 2>/dev/null || die "repo $1"
  cd "$W" || die "cd $1"
  g symbolic-ref HEAD refs/heads/main
  printf 'base\n' > base.txt
  g add base.txt && g commit -q -m 'Initial commit' || die "first commit $1"
  g remote add origin "$R" && g push -q -u origin main 2>/dev/null || die "first push $1"
  for c in gh glab; do echo ok > "$TMP/$c.mode"; : > "$TMP/$c.log"; rm -f "$TMP/$c.body"; done
  M0=$(g rev-parse HEAD)
}
feat() { g switch -q -c "$1" || die "branch $1"; }
chg() { printf 'x\n' > "$1"; } # a new or changed file
hooks() { printf '%s\n' "$1" >> .real-hooks; printf '.real-hooks\n' >> .git/info/exclude; }

# ---------- static ----------
section "static checks"
sh -n "$RS" 2>/dev/null && ok || bad "syntax: real-ship.sh"
[ -x "$RS" ] && ok || bad "real-ship.sh is not executable"
command -v git >/dev/null 2>&1 && ok || bad "this test needs git"

# ---------- 1. full ship ----------
section "full ship"
mkrepo s1; feat feat/one; chg a.txt
before; run
eq "full ship: exit 0" "$RC" 0
eq "full ship: three stdout lines" "$(lines "$OUT")" 3
rx "full ship: line 1" "$(line "$OUT" 1)" '^committed [0-9a-f]{7} "Update 1 file: a\.txt"$'
eq "full ship: line 2" "$(line "$OUT" 2)" "pushed feat/one"
eq "full ship: line 3" "$(line "$OUT" 3)" "[PR #7](https://github.com/o/r/pull/7)"
eq "full ship: line 1 holds the sha7 of HEAD" "$(line "$OUT" 1 | cut -d' ' -f2)" "$(g rev-parse HEAD | cut -c1-7)"
eq "full ship: the bare remote has the commit" "$(g -C "$R" rev-parse refs/heads/feat/one)" "$(g rev-parse HEAD)"
eq "full ship: main on the remote is unchanged" "$(g -C "$R" rev-parse refs/heads/main)" "$M0"
eq "full ship: gh got base, head and title" "$(cat "$TMP/gh.log")" "pr create --base main --head feat/one --title Update 1 file: a.txt --body <body>"
eq "full ship: the commit holds only a.txt" "$(g show --name-only --format= HEAD)" "a.txt"
eq "full ship: the work tree is clean" "$(g status --porcelain)" ""
hasnt "full ship: stderr has no refusal" "$ERR" "refused"

# ---------- 2. protected branches ----------
section "protected branches"
prot() { # prot NAME: refusal on the current branch with a change on disk
  before; run
  refused_clean "$1" "is protected"
  has "$1: next action names --branch" "$(last "$ERR")" "--branch feat/"
}
mkrepo p1; chg a.txt
prot "on main"
g switch -q -c master; prot "on master"
g update-ref refs/remotes/origin/trunk main
g symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk
g switch -q -c trunk; prot "on the default branch of origin/HEAD"
mkrepo p2; hooks 'real-ship.base = develop'; g switch -q -c develop; chg a.txt
prot "on the base from .real-hooks"
mkrepo p3; g switch -q --detach; chg a.txt
before; run
refused_clean "detached HEAD" "detached"
mkrepo p4; chg a.txt; before; run commit
refused_clean "commit mode on main" "is protected"
before; run push
refused_clean "push mode on main" "is protected"

# ---------- 3. --branch ----------
section "--branch"
mkrepo b1; chg a.txt
run --branch feat/x
eq "--branch: exit 0" "$RC" 0
eq "--branch: HEAD is on the new branch" "$(g symbolic-ref --short HEAD)" "feat/x"
eq "--branch: the commit is on the new branch" "$(g show --name-only --format= feat/x)" "a.txt"
eq "--branch: main is unchanged" "$(g rev-parse main)" "$M0"
eq "--branch: the new branch is on the remote" "$(g -C "$R" rev-parse refs/heads/feat/x)" "$(g rev-parse feat/x)"
eq "--branch: gh uses the new branch as head" "$(cat "$TMP/gh.log" | cut -d' ' -f1-6)" "pr create --base main --head feat/x"
mkrepo b2; chg a.txt; g branch exists-1
before; run --branch exists-1
refused_clean "--branch with an existing name" "already exists"
before; run --branch 'bad name'
refused_clean "--branch with an invalid name" "not a valid branch name"
before; run --branch 'a..b'
refused_clean "--branch with a double dot" "not a valid branch name"
before; run --branch main
refused_clean "--branch with a protected name (main)" "protected"
before; run --branch master
refused_clean "--branch with a protected name (master)" "protected"
hooks 'real-ship.base = develop'
before; run --branch develop
refused_clean "--branch with the base name" "protected"
before; run --branch
eq "--branch without a value: exit 2" "$RC" 2
before; run --branch ''
eq "--branch with an empty value: exit 2" "$RC" 2

# ---------- 4. nothing to do ----------
section "nothing to do"
mkrepo n1; feat feat/n
before; run commit
refused_clean "commit mode, clean tree" "nothing to commit"
has "commit mode, clean tree: next action" "$(last "$ERR")" "Next: change a file first."
before; run
refused_clean "full mode, branch equal to base" "nothing to commit or push"
before; run push
refused_clean "push mode, branch equal to base" "nothing to commit or push"
mkdir -p .real; printf 'task\n' > .real/contract.md
before; run commit
refused_clean "only a .real/ file changed" "nothing to commit"

# ---------- 5. secret names ----------
section "secret names"
mkrepo c1; feat feat/c
for f in .env .env.local a.pem id_rsa server.key id_ed25519 cert.p12 credentials.json; do
  chg ok.txt; chg "$f"
  before; run commit
  refused_clean "secret file $f" "secret-like file '$f'"
  eq "secret file $f: nothing is staged" "$(g diff --cached --name-only)" ""
  rm -f "$f"
done
chg .env.example; chg id_rsa.pub; chg ok.txt
run commit
eq "allowed names (.env.example, id_rsa.pub): exit 0" "$RC" 0
eq "allowed names are committed" "$(g show --name-only --format= HEAD | tr '\n' ' ')" ".env.example id_rsa.pub ok.txt "
printf '.env\n' > .gitignore; chg .env; chg a.txt
run commit
eq "an ignored .env: exit 0" "$RC" 0
eq "an ignored .env is not committed" "$(g show --name-only --format= HEAD | tr '\n' ' ')" ".gitignore a.txt "
mkrepo c2; feat feat/c2; chg .env; g add -f .env; g commit -q -m 'track the secret'; rm .env
run commit
eq "a deleted secret file is fine: exit 0" "$RC" 0
eq "a deleted secret file is committed as a deletion" "$(g show --name-status --format= HEAD)" "D	.env"
# D1: a secret that is staged but gone from the work tree is in the index, so the commit would take it.
mkrepo c3; feat feat/c3; printf 'S=1\n' > .env; g add -f .env; rm .env; chg a
H3=$(g rev-parse HEAD)
before; run commit
refused_clean "a staged secret that is gone from the work tree" "secret-like file '.env'"
eq "a staged secret that is gone from the work tree: no new commit" "$(g rev-parse HEAD)" "$H3"
eq "a staged secret that is gone from the work tree: the index is not touched" "$(g diff --cached --name-only)" ".env"
# D6: the secret name match ignores case.
mkrepo c4; feat feat/c4
for f in .ENV Server.PEM ID_RSA .Env.Local; do
  chg ok.txt; chg "$f"
  before; run commit
  refused_clean "secret file $f (other case)" "secret-like file '$f'"
  eq "secret file $f (other case): nothing is staged" "$(g diff --cached --name-only)" ""
  rm -f "$f"
done
chg ID_RSA.PUB; chg .ENV.EXAMPLE; chg ok.txt
run commit
eq "allowed names in upper case (ID_RSA.PUB, .ENV.EXAMPLE): exit 0" "$RC" 0

# ---------- 6. .real/ ----------
section ".real/ folder"
mkrepo r1; feat feat/r; mkdir -p .real; printf 'task\n' > .real/contract.md; chg a.txt
run commit
eq ".real/ untracked: exit 0" "$RC" 0
eq ".real/ untracked: only a.txt is committed" "$(g show --name-only --format= HEAD)" "a.txt"
eq ".real/ untracked: the file stays untracked" "$(g status --porcelain)" "?? .real/"
chg b.txt; g add -f .real/contract.md
before; run commit
refused_clean "a staged .real/ file" "under .real/ is staged"
has "a staged .real/ file: next action" "$(last "$ERR")" "git restore --staged .real"

# ---------- 7. odd file names ----------
section "file names"
mkrepo f1; feat feat/f
printf 'a.txt\nb.txt\n' > .gitignore
mkdir -p "sub dir"; chg "a b.txt"; chg '[ab].txt'; chg a.txt; chg b.txt; chg "sub dir/c.txt"
run commit
eq "odd names: exit 0" "$RC" 0
eq "odd names: exactly the changed files are committed, the ignored a.txt and b.txt are not" "$(g -c core.quotePath=false show --name-only --format= HEAD | tr '\n' '|')" ".gitignore|[ab].txt|a b.txt|sub dir/c.txt|"
eq "odd names: the message has the and-more form" "$(g log -1 --format=%s)" "Update 4 files: .gitignore, [ab].txt, a b.txt and 1 more"
nl='
'
mkrepo f2; feat feat/f2; chg "a${nl}b.txt"
before; run commit
refused_clean "a name with a newline" "special character"

# ---------- 8. commit and push modes ----------
section "commit and push modes"
mkrepo m1; feat feat/m; chg a.txt
before; run commit
eq "commit mode: exit 0" "$RC" 0
eq "commit mode: one stdout line" "$(lines "$OUT")" 1
rx "commit mode: the line" "$OUT" '^committed [0-9a-f]{7} "Update 1 file: a\.txt"$'
eq "commit mode: no push, main on the remote is unchanged" "$(g -C "$R" rev-parse refs/heads/main)" "$M0"
eq "commit mode: the branch is not on the remote" "$(g -C "$R" for-each-ref refs/heads/feat/m)" ""
eq "commit mode: gh is not called" "$(calls)" 0
chg b.txt
run push
eq "push mode: exit 0" "$RC" 0
eq "push mode: two stdout lines" "$(lines "$OUT")" 2
rx "push mode: line 1" "$(line "$OUT" 1)" '^committed [0-9a-f]{7} "Update 1 file: b\.txt"$'
eq "push mode: line 2" "$(line "$OUT" 2)" "pushed feat/m"
eq "push mode: the remote has the branch" "$(g -C "$R" rev-parse refs/heads/feat/m)" "$(g rev-parse HEAD)"
eq "push mode: gh is not called" "$(calls)" 0
run push
eq "push mode with nothing new: exit 0" "$RC" 0
rx "push mode with nothing new: line 1" "$(line "$OUT" 1)" '^nothing to commit, HEAD [0-9a-f]{7} "Update 1 file: b\.txt"$'
eq "push mode with nothing new: line 2" "$(line "$OUT" 2)" "pushed feat/m"

# ---------- 9. clean tree, unpushed commits ----------
section "clean tree with unpushed commits"
mkrepo u1; feat feat/u; chg a.txt; g add a.txt; g commit -q -m 'Local work'
run
eq "unpushed: exit 0" "$RC" 0
eq "unpushed: three stdout lines" "$(lines "$OUT")" 3
rx "unpushed: line 1" "$(line "$OUT" 1)" '^nothing to commit, HEAD [0-9a-f]{7} "Local work"$'
eq "unpushed: line 2" "$(line "$OUT" 2)" "pushed feat/u"
rx "unpushed: line 3" "$(line "$OUT" 3)" '^\[PR #7\]\(https://github\.com/o/r/pull/7\)$'
eq "unpushed: the remote has the commit" "$(g -C "$R" rev-parse refs/heads/feat/u)" "$(g rev-parse HEAD)"
eq "unpushed: gh got the HEAD subject as title" "$(cut -d' ' -f1-9 "$TMP/gh.log")" "pr create --base main --head feat/u --title Local work"

# ---------- 10. dry run ----------
section "dry run"
mkrepo d1; feat feat/d; chg a.txt
before; n0=$(glines); run --dry-run
eq "dry run: exit 0" "$RC" 0
eq "dry run: four lines" "$(lines "$OUT")" 4
eq "dry run: add line" "$(line "$OUT" 1)" "would run: git --literal-pathspecs add --pathspec-from-file=FILE"
eq "dry run: commit line" "$(line "$OUT" 2)" "would run: git commit -m 'Update 1 file: a.txt'"
eq "dry run: push line" "$(line "$OUT" 3)" "would run: git push -u origin refs/heads/feat/d:refs/heads/feat/d"
eq "dry run: pr line" "$(line "$OUT" 4)" "would run: gh pr create --base main --head feat/d --title 'Update 1 file: a.txt' --body '<commit list>'"
still "dry run"
eq "dry run: the file stays untracked" "$(g status --porcelain)" "?? a.txt"
nrx "dry run: git is not asked to switch, add, commit or push" "$(newgit "$n0")" '(^| )(switch|add|commit|push)( |$)'
mkrepo d2; chg a.txt
before; run --dry-run --branch feat/y
eq "dry run with --branch: exit 0" "$RC" 0
eq "dry run with --branch: switch line first" "$(line "$OUT" 1)" "would run: git switch -c feat/y"
eq "dry run with --branch: five lines" "$(lines "$OUT")" 5
still "dry run with --branch"
mkrepo d3 gitlab; feat feat/d3; chg a.txt
run --dry-run
eq "dry run on GitLab: mr line" "$(line "$OUT" 4)" "would run: glab mr create --target-branch main --source-branch feat/d3 --title 'Update 1 file: a.txt' --description '<commit list>' --yes"
run commit --dry-run
eq "dry run in commit mode: two lines" "$(lines "$OUT")" 2

# ---------- 11. base and host settings ----------
section "base and host"
mkrepo h1; feat feat/h; hooks 'real-ship.base = develop'; chg a.txt
run
eq "base from .real-hooks: exit 0" "$RC" 0
has "base from .real-hooks: gh --base" "$(cat "$TMP/gh.log")" "--base develop --head feat/h"
chg b.txt; REAL_SHIP_BASE=release; export REAL_SHIP_BASE
run
has "REAL_SHIP_BASE wins over the file: gh --base" "$(tail -n 1 "$TMP/gh.log")" "--base release --head feat/h"
unset REAL_SHIP_BASE
chg c.txt; printf '' > .real-hooks; g config real.hooks.real-ship.base qa
run
has "base from git config: gh --base" "$(tail -n 1 "$TMP/gh.log")" "--base qa --head feat/h"
mkrepo h2 plain; feat feat/h2; chg a.txt
before; run
refused_clean "unknown host in full mode" "host"
has "unknown host: next action" "$(last "$ERR")" "real-ship.host = github or gitlab"
run push
eq "unknown host in push mode: exit 0" "$RC" 0
chg b.txt; hooks 'real-ship.host = github'
run
eq "real-ship.host = github on an unknown URL: exit 0" "$RC" 0
eq "real-ship.host = github: three lines" "$(lines "$OUT")" 3
eq "real-ship.host = github: gh is called" "$(wc -l < "$TMP/gh.log" | tr -d ' ')" 1
mkrepo h3; feat feat/h3; chg a.txt; hooks 'real-ship.host = svn'
before; run
refused_clean "a bad host value" "host"
mkrepo h5; feat feat/h5; chg a.txt; g update-ref -d refs/remotes/origin/main
before; run
refused_clean "no base is known" "no base branch"
has "no base is known: next action" "$(last "$ERR")" "real-ship.base in .real-hooks"
run push
eq "push mode needs no base: exit 0" "$RC" 0

# ---------- 12. missing CLI and remote ----------
section "missing tools"
mkrepo t1; feat feat/t; chg a.txt
before; runp "$TMP/bin-nocli"
refused_clean "gh missing" "gh not found"
has "gh missing: next action" "$(last "$ERR")" "Next: install gh, or run /real-ship push and open the PR yourself."
eq "gh missing: the work tree is untouched" "$(g status --porcelain)" "?? a.txt"
mkrepo t2 gitlab; feat feat/t2; chg a.txt
before; runp "$TMP/bin-nocli"
refused_clean "glab missing" "glab not found"
has "glab missing: next action" "$(last "$ERR")" "open the MR yourself"
runp "$TMP/bin-nocli" commit
eq "commit mode needs no CLI: exit 0" "$RC" 0
mkrepo t3; feat feat/t3; chg a.txt; g remote remove origin
before; run push
refused_clean "no origin remote" "origin"
cd "$TMP" && mkdir -p nogit && cd nogit || die "nogit"
run
eq "not a git repo: exit 1" "$RC" 1
has "not a git repo: refusal" "$(last "$ERR")" "real-ship: refused: this folder is not in a git work tree. Next:"
mkdir -p "$TMP/empty" && cd "$TMP/empty" && g init -q 2>/dev/null || die "empty repo"
run
eq "a repo with no commit: exit 1" "$RC" 1
has "a repo with no commit: refusal" "$(last "$ERR")" "the repo has no commit"

# ---------- 13. GitLab ----------
section "GitLab"
mkrepo l1 gitlab; feat feat/g; chg a.txt
run
eq "GitLab: exit 0" "$RC" 0
eq "GitLab: line 3" "$(line "$OUT" 3)" "[MR !3](https://gitlab.com/o/r/-/merge_requests/3)"
eq "GitLab: glab got the flags" "$(cat "$TMP/glab.log")" "mr create --target-branch main --source-branch feat/g --title Update 1 file: a.txt --description <body> --yes"
eq "GitLab: gh is not called" "$(wc -l < "$TMP/gh.log" | tr -d ' ')" 0
mkrepo l2 gitlab; feat feat/g2; chg a.txt; echo exists > "$TMP/glab.mode"
run
eq "GitLab, existing MR: exit 0" "$RC" 0
eq "GitLab, existing MR: line 3" "$(line "$OUT" 3)" "[MR !12](https://gitlab.com/o/r/-/merge_requests/12)"
mkrepo l3 gitlab; feat feat/g3; chg a.txt; hooks 'real-ship.host = github'
run
has "host override to github on a GitLab path: gh is called" "$(cat "$TMP/gh.log")" "pr create"

# ---------- 13b. host from the host part of the URL (D2) ----------
section "host from the URL"
HU=0
AT=@ # The URLs below are built from parts, so no text in this file looks like an email address.
U1="git${AT}github.com:o/gitlab-mirror.git"
hostof() { # hostof URL: dry run in a new repo whose origin URL is URL. The push goes to the bare remote.
  HU=$((HU + 1)); mkrepo "hu$HU" plain; feat feat/u; chg a.txt
  g remote set-url origin "$1"; g config "url.$R.pushInsteadOf" "$1"
  run --dry-run
}
hostof "$U1"
eq "github host, gitlab in the path: exit 0" "$RC" 0
has "github host, gitlab in the path: gh" "$(line "$OUT" 4)" "would run: gh pr create"
hostof 'https://gitlab.example.com/o/github-tools.git'
has "gitlab host, github in the path: glab" "$(line "$OUT" 4)" "would run: glab mr create"
hostof "ssh://git${AT}gitlab.example.com:2222/o/r.git"
has "ssh URL with a port: glab" "$(line "$OUT" 4)" "would run: glab mr create"
hostof "https://user:pw${AT}github.com/o/r.git"
has "https URL with a user: gh" "$(line "$OUT" 4)" "would run: gh pr create"
hostof "git${AT}example.com:o/github.git"
eq "an unknown host with github in the path: refused" "$RC" 1
hasnt "an unknown host with github in the path: no would-run line" "$OUT" "would run"
HU=$((HU + 1)); mkrepo "hu$HU" plain; feat feat/u; chg a.txt
g remote set-url origin "$U1"; g config "url.$R.pushInsteadOf" "$U1"
run
eq "github host, gitlab in the path, real run: exit 0" "$RC" 0
eq "github host, gitlab in the path, real run: line 3" "$(line "$OUT" 3)" "[PR #7](https://github.com/o/r/pull/7)"
eq "github host, gitlab in the path, real run: the bare remote has the branch" "$(g -C "$R" rev-parse refs/heads/feat/u)" "$(g rev-parse HEAD)"
# D7: a relative local origin and a file:// URL have no host part. The whole URL is matched.
for k in github gitlab; do
  mkrepo "rel-$k" "$k"; feat feat/rel; chg a.txt
  g remote set-url origin "../../$k/rel-$k.git"
  run --dry-run
  eq "relative origin on a $k path: dry run exit 0" "$RC" 0
  case $k in github) cli=gh ;; *) cli=glab ;; esac
  has "relative origin on a $k path: $cli" "$(line "$OUT" 4)" "would run: $cli "
  run
  eq "relative origin on a $k path: real run exit 0" "$RC" 0
  eq "relative origin on a $k path: three lines" "$(lines "$OUT")" 3
  eq "relative origin on a $k path: the bare remote has the branch" "$(g -C "$R" rev-parse refs/heads/feat/rel)" "$(g rev-parse HEAD)"
  eq "relative origin on a $k path: $cli is called once" "$(wc -l < "$TMP/$cli.log" | tr -d ' ')" 1
  mkrepo "fu-$k" "$k"; feat feat/fu; chg a.txt
  g remote set-url origin "file://$R"
  run --dry-run
  has "file:// origin on a $k path: $cli" "$(line "$OUT" 4)" "would run: $cli "
done

# ---------- 13c. push refspec (D3) ----------
section "push refspec"
mkrepo w1; feat feat/w; chg a.txt
g config remote.origin.push refs/heads/feat/w:refs/heads/main
run push
eq "remote.origin.push to main: exit 0" "$RC" 0
eq "remote.origin.push to main: line 2" "$(line "$OUT" 2)" "pushed feat/w"
eq "remote.origin.push to main: main on the remote is unchanged" "$(g -C "$R" rev-parse refs/heads/main)" "$M0"
eq "remote.origin.push to main: the remote has the branch at HEAD" "$(g -C "$R" rev-parse refs/heads/feat/w)" "$(g rev-parse HEAD)"
eq "remote.origin.push to main: the branch tracks its own name" "$(g config branch.feat/w.merge)" "refs/heads/feat/w"

# ---------- 14. PR errors ----------
section "PR errors"
mkrepo e1; feat feat/e; chg a.txt; echo exists > "$TMP/gh.mode"
run
eq "existing PR: exit 0" "$RC" 0
eq "existing PR: line 3" "$(line "$OUT" 3)" "[PR #12](https://github.com/o/r/pull/12)"
eq "existing PR: three lines" "$(lines "$OUT")" 3
has "existing PR: the CLI text is on stderr" "$ERR" "a request already exists"
mkrepo e2; feat feat/e2; chg a.txt; echo fail > "$TMP/gh.mode"
run
eq "plain CLI failure: exit 1" "$RC" 1
eq "plain CLI failure: stdout has the commit and push lines" "$(lines "$OUT")" 2
has "plain CLI failure: refusal says the branch is pushed" "$(last "$ERR")" "the PR was not created. The branch feat/e2 is pushed. Next: read the message above, then run /real-ship again."
has "plain CLI failure: the CLI text is on stderr" "$ERR" "the server said no"
eq "plain CLI failure: the branch is on the remote" "$(g -C "$R" rev-parse refs/heads/feat/e2)" "$(g rev-parse HEAD)"
mkrepo e3; feat feat/e3; chg a.txt; echo nourl > "$TMP/gh.mode"
run
eq "no link in the output: exit 1" "$RC" 1
has "no link in the output: refusal" "$(last "$ERR")" "real-ship: refused: gh gave no link. Next: run gh pr view feat/e3."
mkrepo e4 gitlab; feat feat/e4; chg a.txt; echo nourl > "$TMP/glab.mode"
run
has "no link on GitLab: refusal" "$(last "$ERR")" "glab gave no link. Next: run glab mr view feat/e4."
mkrepo e5 gitlab; feat feat/e5; chg a.txt; echo fail > "$TMP/glab.mode"
run
has "GitLab failure: refusal says MR" "$(last "$ERR")" "the MR was not created. The branch feat/e5 is pushed."

# ---------- 14b. link and error text (D4, D5) ----------
section "link and error text"
mkrepo e6 gitlab; feat feat/e6; chg a.txt; echo tty > "$TMP/glab.mode"
run
eq "link after a space on its own line (TTY form): exit 0" "$RC" 0
eq "link after a space on its own line (TTY form): line 3" "$(line "$OUT" 3)" "[MR !3](https://gitlab.com/o/r/-/merge_requests/3)"
mkrepo e7; feat feat/e7; chg a.txt; echo authfail > "$TMP/gh.mode"
run
eq "a failure with a pull URL and no already-exists text: exit 1" "$RC" 1
eq "a failure with a pull URL and no already-exists text: no link line" "$(lines "$OUT")" 2
hasnt "a failure with a pull URL and no already-exists text: no PR line" "$OUT" "[PR"
has "a failure with a pull URL and no already-exists text: refusal" "$(last "$ERR")" "the PR was not created. The branch feat/e7 is pushed."

# ---------- 15. rejected push ----------
section "rejected push"
mkrepo x1; feat feat/x; chg a.txt
printf '#!/bin/sh\necho "remote says no" >&2\nexit 1\n' > "$R/hooks/pre-receive"; chmod +x "$R/hooks/pre-receive"
run
eq "rejected push: exit 1" "$RC" 1
eq "rejected push: stdout has line 1 only" "$(lines "$OUT")" 1
rx "rejected push: line 1" "$OUT" '^committed [0-9a-f]{7} "Update 1 file: a\.txt"$'
has "rejected push: the commit stays" "$(last "$ERR")" "real-ship: refused: the push failed. The commit $(g rev-parse HEAD | cut -c1-7) stays on feat/x. Next: fix the cause above, then run the same /real-ship command again."
has "rejected push: the remote text is on stderr" "$ERR" "remote says no"
eq "rejected push: the local branch has the commit" "$(g show --name-only --format= feat/x)" "a.txt"
eq "rejected push: the branch is not on the remote" "$(g -C "$R" for-each-ref refs/heads/feat/x)" ""
eq "rejected push: gh is not called" "$(calls)" 0

# ---------- 16. repo hooks ----------
section "repo hooks"
mkrepo k1; feat feat/k; chg a.txt
printf '#!/bin/sh\necho "hook says no" >&2\nexit 1\n' > .git/hooks/pre-commit; chmod +x .git/hooks/pre-commit
before; run
eq "failing pre-commit: exit 1" "$RC" 1
eq "failing pre-commit: stdout is empty" "$OUT" ""
has "failing pre-commit: refusal" "$(last "$ERR")" "real-ship: refused: the commit failed. Next: fix the problem above, then run /real-ship again."
has "failing pre-commit: the hook text is on stderr" "$ERR" "hook says no"
eq "failing pre-commit: no commit was made" "$(g rev-parse HEAD)" "$M0"
eq "failing pre-commit: no push" "$(g -C "$R" for-each-ref refs/heads/feat/k)" ""
eq "failing pre-commit: gh is not called" "$(calls)" 0
printf '#!/bin/sh\necho ran > "%s/pre-commit-ran"\n' "$TMP" > .git/hooks/pre-commit
printf '#!/bin/sh\necho ran > "%s/pre-push-ran"\n' "$TMP" > .git/hooks/pre-push
chmod +x .git/hooks/pre-push
run
eq "passing hooks: exit 0" "$RC" 0
eq "the pre-commit hook ran" "$(cat "$TMP/pre-commit-ran" 2>/dev/null)" "ran"
eq "the pre-push hook ran" "$(cat "$TMP/pre-push-ran" 2>/dev/null)" "ran"

# ---------- 17. commit message ----------
section "commit message"
mkrepo g1; feat feat/m1; chg a.txt; chg b.txt
run commit
eq "two files: message" "$(g log -1 --format=%s)" "Update 2 files: a.txt, b.txt"
mkdir -p d; chg c.txt; chg d/x.txt; chg e.txt; chg f.txt; chg g.txt
run commit
eq "five files: and-more form with basenames" "$(g log -1 --format=%s)" "Update 5 files: c.txt, x.txt, e.txt and 2 more"
hasnt "five files: stderr has no language warning" "$ERR" "warning"
chg h.txt; REAL_SHIP_LANGUAGE=xx; export REAL_SHIP_LANGUAGE
run commit
eq "unknown language: exit 0" "$RC" 0
eq "unknown language: the message stays English" "$(g log -1 --format=%s)" "Update 1 file: h.txt"
has "unknown language: warning on stderr" "$ERR" "real-ship: warning: no message template for language 'xx'. The message is in English. Use -m for another language."
chg i.txt; run commit -m 'Own words'
hasnt "unknown language with -m: no warning" "$ERR" "warning"
REAL_SHIP_LANGUAGE=en; chg j.txt
run commit
hasnt "language en: no warning" "$ERR" "warning"
unset REAL_SHIP_LANGUAGE
mkrepo g2; feat feat/m2; chg a.txt
run -m 'Fix the thing'
eq "-m: line 1" "$(line "$OUT" 1 | cut -d' ' -f1,3-)" 'committed "Fix the thing"'
eq "-m: the commit subject" "$(g log -1 --format=%s)" "Fix the thing"
has "-m: the PR title" "$(cat "$TMP/gh.log")" "--title Fix the thing --body"
before; run -m
eq "-m without a value: exit 2" "$RC" 2
run -m ''
eq "-m with an empty value: exit 2" "$RC" 2

# ---------- 18. suite marker ----------
section "suite marker"
SUITELOG=$TMP/suite.log
mkrepo q1; feat feat/q; chg a.txt
REAL_SHIP_SUITE="echo suite-ran >> '$SUITELOG'; echo suite-out"; export REAL_SHIP_SUITE
before; run
refused_clean "suite set, no marker" "the long test suite has not passed on this state"
has "suite set, no marker: next action" "$(last "$ERR")" "Next: run real-ship.sh suite, then run /real-ship again."
run commit
eq "commit mode ignores the marker: exit 0" "$RC" 0
chg b.txt
run push
eq "push mode: refused without a marker" "$RC" 1
before; run --no-suite-check
eq "--no-suite-check: exit 0" "$RC" 0
has "--no-suite-check: warning" "$ERR" "real-ship: warning: the long test suite has not passed on this state. --no-suite-check is set, so the ship continues."
eq "--no-suite-check: three stdout lines" "$(lines "$OUT")" 3
mkrepo q2; feat feat/q2; chg a.txt
run suite
eq "suite: exit 0" "$RC" 0
rx "suite: stdout" "$OUT" '^suite passed [0-9a-f]{7}$'
eq "suite: one stdout line" "$(lines "$OUT")" 1
has "suite: the suite output is on stderr" "$ERR" "suite-out"
eq "suite: the command ran once" "$(wc -l < "$SUITELOG" | tr -d ' ')" 1
[ -s "$(g rev-parse --git-path real-suite-ok)" ] && ok || bad "suite: no marker file"
eq "suite: the marker is not in the work tree" "$(g status --porcelain)" "?? a.txt"
run commit
eq "suite then commit: exit 0" "$RC" 0
run push
eq "commit then push keeps the marker valid: exit 0" "$RC" 0
eq "commit then push: two stdout lines" "$(lines "$OUT")" 2
chg b.txt
before; run push
refused_clean "a file change makes the marker stale" "the long test suite has not passed on this state"
run suite
eq "suite again: exit 0" "$RC" 0
run
eq "full ship after the suite: exit 0" "$RC" 0
eq "full ship after the suite: three lines" "$(lines "$OUT")" 3
chg c.txt; rm -f "$(g rev-parse --git-path real-suite-ok)"
run suite --dry-run
eq "suite with an option: exit 2" "$RC" 2
mkrepo q3; feat feat/q3; chg a.txt
REAL_SHIP_SUITE='exit 3'
run suite
eq "failing suite: exit 1" "$RC" 1
has "failing suite: refusal" "$(last "$ERR")" "real-ship: refused: the long test suite failed (exit 3). Next: fix it, then run real-ship.sh suite again."
eq "failing suite: no marker" "$(ls "$(g rev-parse --git-path real-suite-ok)" 2>/dev/null)" ""
eq "failing suite: stdout is empty" "$OUT" ""
unset REAL_SHIP_SUITE
run suite
eq "suite with no command: exit 1" "$RC" 1
has "suite with no command: refusal" "$(last "$ERR")" "real-ship: refused: no long suite is set. Next: set real-ship.suite in .real-hooks."
hooks 'real-ship.suite = true'
run suite
eq "suite from .real-hooks: exit 0" "$RC" 0

# ---------- 19. PR body ----------
section "PR body"
mkrepo y1; feat feat/y; chg a.txt; g add a.txt; g commit -q -m 'First change'; chg b.txt
run
eq "body: exit 0" "$RC" 0
eq "body without a contract: the commit list" "$(cat "$TMP/gh.body")" "Commits:
- First change
- Update 1 file: b.txt"
mkdir -p "$TMP/ctr"
cp "$RS" "$TMP/ctr/real-ship.sh"
printf '#!/bin/sh\n[ "$1" = report ] || exit 2\nprintf "REPORT-STUB root=%%s\\n" "$REAL_CONTRACT_ROOT"\n' > "$TMP/ctr/real-contract.sh"
mkrepo y2; feat feat/y2; mkdir -p .real; printf 'task\n' > .real/contract.md; chg a.txt
SCRIPT=$TMP/ctr/real-ship.sh; run; SCRIPT=$RS
eq "body with a contract: exit 0" "$RC" 0
eq "body with a contract: the commit list, an empty line, the report" "$(cat "$TMP/gh.body")" "Commits:
- Update 1 file: a.txt

REPORT-STUB root=$W"
eq "body with a contract: .real/ is not committed" "$(g show --name-only --format= HEAD)" "a.txt"
mkrepo y3; feat feat/y3; mkdir -p .real; printf 'task\n' > .real/contract.md; chg a.txt
printf '#!/bin/sh\nexit 1\n' > "$TMP/ctr/real-contract.sh"
SCRIPT=$TMP/ctr/real-ship.sh; run; SCRIPT=$RS
eq "failing report: exit 0" "$RC" 0
has "failing report: warning" "$ERR" "real-ship: warning: real-contract.sh report failed. The body has the commit list only."
eq "failing report: the commit list stays" "$(cat "$TMP/gh.body")" "Commits:
- Update 1 file: a.txt"
rm -f "$TMP/ctr/real-contract.sh"
mkrepo y4; feat feat/y4; mkdir -p .real; printf 'task\n' > .real/contract.md; chg a.txt
SCRIPT=$TMP/ctr/real-ship.sh; run; SCRIPT=$RS
eq "contract without real-contract.sh: the commit list only" "$(cat "$TMP/gh.body")" "Commits:
- Update 1 file: a.txt"

# ---------- 20. bad input ----------
section "bad input"
mkrepo i1; feat feat/i; chg a.txt
for a in --force --no-verify -a --bogus deploy -f -n --all --branch=x; do
  before; run "$a"
  eq "unknown argument $a: exit 2" "$RC" 2
  eq "unknown argument $a: the message" "$ERR" "real-ship: unknown argument: $a. Next: run real-ship.sh --help."
  still "unknown argument $a"
done
before; run commit push
eq "two mode words: exit 2" "$RC" 2
eq "two mode words: the message" "$ERR" "real-ship: unknown argument: push. Next: run real-ship.sh --help."
still "two mode words"
run commit --force
eq "a known mode with an unknown flag: exit 2" "$RC" 2
run --help
eq "--help: exit 0" "$RC" 0
has "--help: usage" "$OUT" "real-ship.sh [commit|push] [-m MESSAGE] [--branch NAME] [--dry-run] [--no-suite-check]"
eq "--help: nothing on stderr" "$ERR" ""
run -h
eq "-h: exit 0" "$RC" 0
eq "no unknown-argument run changed the repo: the file is still untracked" "$(g status --porcelain)" "?? a.txt"

# ---------- 21. what the calls looked like ----------
section "call logs"
CLI=$(cat "$TMP/all-cli.log")
[ -n "$(cat "$GITLOG")" ] && ok || bad "the git wrapper log is empty"
has "the git log has a push with a full refspec" "$(cat "$GITLOG")" "push -u origin refs/heads/feat/"
eq "every git push call has a full refspec" "$(grep '^push ' "$GITLOG" | grep -Evc '^push -u origin refs/heads/[^ :]+:refs/heads/[^ :]+$')" 0
has "the git log has a literal-pathspec add" "$(cat "$GITLOG")" "--literal-pathspecs add --pathspec-from-file="
has "the gh log has a PR create" "$CLI" "pr create"
has "the glab log has an MR create" "$CLI" "mr create"
nrx "no --force, --no-verify, --all or hooksPath in a git call" "$(cat "$GITLOG")" '--force|--no-verify|--all|hooksPath'
nrx "no -f or + refspec in a push" "$(cat "$GITLOG")" '(^| )push( .*)? (-f|\+)'
nrx "no add -A, add ., add -u" "$(cat "$GITLOG")" '(^| )add (-A|-u|\.)( |$)'
nrx "no commit -a" "$(cat "$GITLOG")" '(^| )commit .* -[a-z]*a[a-z]*( |$)'
nrx "no git merge" "$(cat "$GITLOG")" '(^| )merge( |$)'
nrx "no gh or glab merge, no auto-merge, no --force" "$CLI" '(^| )merge( |$)|auto-merge|--force'

echo
printf 'passed: %d, failed: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
