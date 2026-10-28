#!/bin/sh
# Test scripts/real-await.sh in temporary repos. POSIX sh. Needs git and curl. python3 is optional (it serves a real local page).
# The script uses a temporary HOME, a temporary state folder, a temporary TMPDIR and stubs for notify-send, gh, glab and curl.
# It does not touch your files or your git config. It stops only the processes that it started, and it removes only its own folder.
# A run that must time out takes real seconds, so independent runs go in parallel. The test takes about 1 to 2 minutes.
# A busy machine makes every process start slow. The script measures that once and widens the upper time limits.
# Usage: sh scripts/test-real-await.sh
#   REAL_TEST_SH='bash --posix' sh scripts/test-real-await.sh   runs the script under test in another shell
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
RA=$ROOT/scripts/real-await.sh
RS=$ROOT/scripts/real-status.sh
# The shell that runs the script under test, as a full path (a test PATH can hide it).
set -- ${REAL_TEST_SH:-sh}
SH="$(command -v "$1") $(shift; printf '%s' "$*")"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/real-await-test.XXXXXX") || exit 1
TMP=$(cd "$TMP" && pwd -P)
PIDS=
kill_if() { # kill_if SIGNAL PID NEEDLE: signal PID only when it is alive and its command line holds NEEDLE
  case $2 in ''|*[!0-9]*) return 0 ;; esac
  kill -0 "$2" 2>/dev/null || return 0
  case $(ps -ww -p "$2" -o args= 2>/dev/null) in *"$3"*) kill "-$1" "$2" 2>/dev/null ;; esac
  return 0
}
track() { PIDS="$PIDS $1:$2"; } # track PID NEEDLE: the test stops it at the end
cleanup() {
  for e in $PIDS; do kill_if TERM "${e%%:*}" "${e#*:}"; done
  # A parallel run leaves its PID in a file. The command line must hold the script path.
  for f in "$TMP"/par/*/pid; do [ -f "$f" ] && kill_if TERM "$(cat "$f")" "$RA"; done
  rm -rf "$TMP"
}
trap cleanup EXIT
trap 'exit 1' INT TERM

# Isolated environment
mkdir -p "$TMP/home" "$TMP/state" "$TMP/config" "$TMP/tmp" "$TMP/stubs" "$TMP/curlstub" "$TMP/log" "$TMP/par"
export HOME="$TMP/home"
export XDG_STATE_HOME="$TMP/state"
export XDG_CONFIG_HOME="$TMP/config"
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=tester GIT_AUTHOR_EMAIL=tester.invalid
export GIT_COMMITTER_NAME=tester GIT_COMMITTER_EMAIL=tester.invalid
export GIT_CEILING_DIRECTORIES="$TMP"
export TMPDIR="$TMP/tmp"
for v in $(env | sed -n 's/^\(REAL_[A-Za-z_]*\)=.*/\1/p'); do unset "$v"; done
unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
export NO_PROXY=127.0.0.1 no_proxy=127.0.0.1
export REAL_NOTIFY_OS=Linux
export STUB_LOG="$TMP/log"

. "$ROOT/hooks/claude/real-state-lib.sh"

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; [ -n "${2:-}" ] && printf '      %s\n' "$2"; return 0; }
section() { printf '== %s\n' "$1"; }
eq() { if [ "$2" = "$3" ]; then ok; else bad "$1" "expected '$3', got '$2'"; fi; }
has() { case $2 in *"$3"*) ok ;; *) bad "$1" "missing text: $3 | in: $2" ;; esac; }
hasnt() { case $2 in *"$3"*) bad "$1" "unexpected text: $3 | in: $2" ;; *) ok ;; esac; }
rx() { if printf '%s\n' "$2" | grep -Eq -e "$3"; then ok; else bad "$1" "no match for $3 in: $2"; fi; }
within() { if [ "$2" -ge "$3" ] && [ "$2" -le "$4" ]; then ok; else bad "$1" "$2 is not in $3..$4"; fi; } # within NAME VALUE LOW HIGH

# Load slack: the time that 20 process starts take. It is 0 or 1 on a quiet machine.
c0=$(date +%s); i=0
while [ "$i" -lt 20 ]; do date >/dev/null; i=$((i + 1)); done
LOOSE=$(( ($(date +%s) - c0) * 2 ))
[ "$LOOSE" -le 60 ] || LOOSE=60

# Stubs. The notifier, gh, glab and curl write one line for each call to $STUB_LOG.
cat > "$TMP/stubs/notify-send" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$STUB_LOG/notify.log"
EOF
cat > "$TMP/stubs/gh" <<'EOF'
#!/bin/sh
printf 'gh %s|GH_PROMPT_DISABLED=%s\n' "$*" "${GH_PROMPT_DISABLED:-}" >> "$STUB_LOG/gh.log"
[ "${STUB_GH:-OPEN}" = FAIL ] && { echo 'gh: network error' >&2; exit 1; }
printf '%s\n' "${STUB_GH:-OPEN}"
EOF
cat > "$TMP/stubs/glab" <<'EOF'
#!/bin/sh
printf 'glab %s\n' "$*" >> "$STUB_LOG/glab.log"
[ "${STUB_GLAB:-opened}" = FAIL ] && exit 1
if [ -n "${STUB_GLAB_FIRST:-}" ]; then
  printf '{"author":{"id":2,"state":"active"},"iid":18,"state":"%s"}\n' "${STUB_GLAB:-opened}"
else
  printf '{"id":1,"iid":18,"title":"t","state":"%s","author":{"id":2,"state":"active"}}\n' "${STUB_GLAB:-opened}"
fi
EOF
cat > "$TMP/curlstub/curl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$STUB_LOG/curl.log"
o=
while [ $# -gt 0 ]; do case $1 in -o) o=$2; shift ;; esac; shift; done
[ -n "$o" ] && printf '%s' "${STUB_BODY:-}" > "$o"
printf '%s' "${STUB_CODE:-200}"
EOF
chmod +x "$TMP/stubs/notify-send" "$TMP/stubs/gh" "$TMP/stubs/glab" "$TMP/curlstub/curl"
PATH="$TMP/stubs:$PATH"
export PATH

# A PATH that holds a link to each tool that the script needs, and only the stubs that the test names. It hides gh, glab or curl.
mkfarm() { # mkfarm NAME [STUB...]: makes $TMP/farm-NAME and prints it
  d=$TMP/farm-$1; shift
  mkdir -p "$d"
  for t in sh dash bash git awk sed tr head tail cat date sleep ps wc mktemp rm mkdir mv cksum dirname basename grep cut sort od ls chmod uname env jq touch; do
    p=$(command -v "$t" 2>/dev/null) && case $p in /*) ln -sf "$p" "$d/$t" ;; esac
  done
  for s in "$@"; do ln -sf "$TMP/stubs/$s" "$d/$s"; done
  printf '%s\n' "$d"
}
FARM_NONE=$(mkfarm none notify-send)
FARM_GLAB=$(mkfarm glab notify-send glab)
FARM_GH=$(mkfarm gh notify-send gh)

# The script under test. RUN_PATH replaces PATH and RUN_ENV adds variables (words without spaces) for the next runs.
RUN_PATH=; RUN_ENV=
RC=0; OUT=; ERR=; DUR=0
run() { # run ARGS. Runs real-await.sh with no input. Sets RC, OUT, ERR and DUR (whole seconds).
  s0=$(date +%s)
  RC=0
  env ${RUN_PATH:+"PATH=$RUN_PATH"} $RUN_ENV $SH "$RA" "$@" >"$TMP/out" 2>"$TMP/err" </dev/null || RC=$?
  DUR=$(( $(date +%s) - s0 ))
  OUT=$(cat "$TMP/out"); ERR=$(cat "$TMP/err")
}
par() { # par NAME ARGS: like run, in the background. Read the result with join NAME. Join it before the next section.
  pn=$1; shift
  rm -rf "$TMP/par/$pn"; mkdir -p "$TMP/par/$pn"
  (
    s0=$(date +%s); r=0
    env ${RUN_PATH:+"PATH=$RUN_PATH"} $RUN_ENV $SH "$RA" "$@" >"$TMP/par/$pn/out" 2>"$TMP/par/$pn/err" </dev/null &
    echo $! > "$TMP/par/$pn/pid"
    wait $! || r=$?
    echo $(( $(date +%s) - s0 )) > "$TMP/par/$pn/dur"
    echo "$r" > "$TMP/par/$pn/rc"
  ) &
}
join() { # join NAME: waits for par NAME. Sets RC, OUT, ERR and DUR.
  ji=0
  until [ -f "$TMP/par/$1/rc" ] || [ "$ji" -ge 120 ]; do sleep 1; ji=$((ji + 1)); done
  RC=$(cat "$TMP/par/$1/rc" 2>/dev/null); DUR=$(cat "$TMP/par/$1/dur" 2>/dev/null)
  OUT=$(cat "$TMP/par/$1/out" 2>/dev/null); ERR=$(cat "$TMP/par/$1/err" 2>/dev/null)
  [ -n "$RC" ] || { RC=none; bad "a parallel run ended: $1"; }
}
BGPID=
bg() { # bg OUTFILE ARGS. Starts real-await.sh in the background. Sets BGPID.
  o=$1; shift
  env ${RUN_PATH:+"PATH=$RUN_PATH"} $RUN_ENV $SH "$RA" "$@" >"$o" 2>&1 </dev/null &
  BGPID=$!
  track "$BGPID" real-await
}
gone() { # gone PID: the process ended or is a zombie
  gs=$(ps -p "$1" -o stat= 2>/dev/null)
  case $gs in ''|Z*) return 0 ;; esac
  return 1
}
LATE=0
waitend() { # waitend PID SECONDS. Waits for the end of a background run, then sets RC. A late run gets TERM and LATE=1.
  wi=0
  while ! gone "$1" && [ "$wi" -lt "$2" ]; do sleep 1; wi=$((wi + 1)); done
  LATE=0
  gone "$1" || { LATE=1; kill_if TERM "$1" real-await; }
  RC=0; wait "$1" || RC=$?
}
until_true() { # until_true SECONDS CMD...: runs CMD once a second until it succeeds or the time is up
  ut=$1; shift
  while :; do
    "$@" && return 0
    [ "$ut" -gt 0 ] || return 1
    ut=$((ut - 1)); sleep 1
  done
}
lastline() { printf '%s\n' "$OUT" | tail -n 1; }
nlines() { if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else echo 0; fi; }
nnotify() { nlines "$STUB_LOG/notify.log"; }
nwait() { ls "$SD"/wait.* 2>/dev/null | wc -l | tr -d ' '; }
nwait_is() { [ "$(nwait)" = "$1" ]; }
file_is() { [ -s "$1" ]; }
ntmp() { ls "$TMP/tmp" | grep -c '^real-await\.'; } # temp folders of the script under test
reset_log() { rm -f "$STUB_LOG"/*.log; }
rep() { awk -v c="$1" -v n="$2" 'BEGIN { for (i = 0; i < n; i++) printf "%s", c }'; }
n=0
mkrepo() { # sets R (the physical path) and SD (its state folder), and goes there. The state folder gets its root file at once.
  n=$((n + 1)); R=$TMP/repo$n
  git init -q -b main "$R"
  R=$(cd "$R" && pwd -P)
  SD=$(rs_dir "$R")
  cd "$R" || exit 1
  rs_write "$SD" turn_start "$(date +%s)" "$R"
}
sleeper() { sleep 300 >/dev/null 2>&1 </dev/null & SLP=$!; track "$SLP" sleep; } # sets SLP
newdead() { sh -c 'exit 0' & DP=$!; wait "$DP"; } # sets DP, a PID that ended just now
SOUT=
srun() { SOUT=$(env $SH "$RS" "$R" 2>&1); } # real-status

tok=ghp_$(rep a 30)
AT=$(printf '\100') # the at sign, for a URL with a user name and a password

# ---------- usage ----------
section "usage"
RC=0; OUT=$($SH "$RA" --help 2>&1) || RC=$?
eq "--help exits 0" "$RC" 0
has "--help prints the usage" "$OUT" "Usage:"
has "--help shows the probes" "$OUT" "real-await.sh pr NUMBER"
RC=0; OUT2=$($SH "$RA" -h 2>&1) || RC=$?
eq "-h exits 0" "$RC" 0
eq "-h prints the same text" "$OUT2" "$OUT"

# ---------- case 1: each probe passes and times out ----------
section "case 1: each probe passes and times out"
mkrepo
W=$TMP/w1; mkdir -p "$W"
RUN_PATH=; RUN_ENV=
# The runs that time out start together.
par f_to file "$W/none-*.txt" --interval 1 --timeout 1 --no-notify
par c_to cmd "test -f $W/flag" --interval 1 --timeout 1 --no-notify
sleeper; SL=$SLP
par p_to pid "$SL" --interval 1 --timeout 1 --no-notify
RUN_PATH="$TMP/curlstub:$PATH"
RUN_ENV="STUB_CODE=404"; par h_to http http://stub.invalid/ready --interval 1 --timeout 1 --no-notify
RUN_ENV="STUB_CODE=200 STUB_BODY=welcome-home"
par h_to2 http http://stub.invalid/ready --contains 'nothere' --interval 1 --timeout 1 --no-notify
par h_to3 http http://stub.invalid/ready --contains 'w.l' --interval 1 --timeout 1 --no-notify
RUN_PATH=; RUN_ENV="STUB_GH=OPEN"; par r_to pr 18 --interval 1 --timeout 1 --no-notify
RUN_ENV=

printf 'data\n' > "$W/ready.txt"
run file "$W/ready.txt" --stable 1 --interval 1 --timeout 30 --no-notify
eq "file: pass exits 0" "$RC" 0
rx "file: pass last line" "$(lastline)" '^HUMAN_STEP_DONE after [0-9]+s$'
mkdir -p "$HOME/Downloads"; printf 'x\n' > "$HOME/Downloads/x.pdf"
run file '~/Downloads/x.pdf' --stable 1 --interval 1 --timeout 30 --no-notify
eq "file: a leading ~/ is the home folder" "$RC" 0
printf 'x\n' > "$W/with space.txt"
run file "$W/with space*" --stable 1 --interval 1 --timeout 30 --no-notify
eq "file: a name with a space matches (no field splitting)" "$RC" 0
join f_to
eq "file: timeout exits 3" "$RC" 3
eq "file: timeout last line" "$(lastline)" HUMAN_STEP_TIMEOUT

# http with the curl stub
RUN_PATH="$TMP/curlstub:$PATH"; RUN_ENV="STUB_CODE=200"
run http http://stub.invalid/ready --interval 1 --timeout 30 --no-notify
eq "http (stub): pass exits 0" "$RC" 0
rx "http (stub): pass last line" "$(lastline)" '^HUMAN_STEP_DONE after [0-9]+s$'
RUN_ENV="STUB_CODE=404"
run http http://stub.invalid/ready --status 404 --interval 1 --timeout 30 --no-notify
eq "http (stub): --status 404 passes on a 404" "$RC" 0
RUN_ENV="STUB_CODE=200 STUB_BODY=welcome-home"
run http http://stub.invalid/ready --contains come-ho --interval 1 --timeout 30 --no-notify
eq "http (stub): --contains finds the text" "$RC" 0
join h_to
eq "http (stub): a 404 times out" "$RC" 3
eq "http (stub): timeout last line" "$(lastline)" HUMAN_STEP_TIMEOUT
join h_to2
eq "http (stub): --contains with another text times out" "$RC" 3
join h_to3
eq "http (stub): --contains is a fixed string, not a regex" "$RC" 3
RUN_PATH=; RUN_ENV=

# http with a real local server
if command -v python3 >/dev/null 2>&1; then
  mkdir -p "$W/www"; printf '<p>hello-ready</p>\n' > "$W/www/index.html"
  PORT=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
  python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$W/www" >"$TMP/srv.log" 2>&1 </dev/null &
  SRV=$!; track "$SRV" http.server
  up() { curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$PORT/index.html"; }
  if until_true $((8 + LOOSE)) up; then
    par s_to1 http "http://127.0.0.1:$PORT/missing.html" --interval 1 --timeout 1 --no-notify
    par s_to2 http "http://127.0.0.1:$PORT/index.html" --contains 'not on the page' --interval 1 --timeout 1 --no-notify
    run http "http://127.0.0.1:$PORT/index.html" --contains hello-ready --interval 1 --timeout 30 --no-notify
    eq "http (local server): pass exits 0" "$RC" 0
    rx "http (local server): pass last line" "$(lastline)" '^HUMAN_STEP_DONE after [0-9]+s$'
    join s_to1
    eq "http (local server): a missing page times out" "$RC" 3
    eq "http (local server): timeout last line" "$(lastline)" HUMAN_STEP_TIMEOUT
    join s_to2
    eq "http (local server): a text that is missing times out" "$RC" 3
    # URL globbing is off: a pass at the first try is one request, to the literal path.
    for gp in '[1-3]' '{a,b}'; do
      g0=$(grep -c 'GET /' "$TMP/srv.log")
      run http "http://127.0.0.1:$PORT/$gp" --status 404 --interval 1 --timeout 30 --no-notify
      g1=$(grep -c 'GET /' "$TMP/srv.log")
      eq "http (local server): $gp passes on its own 404, exit 0" "$RC" 0
      eq "http (local server): $gp makes exactly one request" "$((g1 - g0))" 1
      has "http (local server): $gp is requested as written" "$(tail -n 1 "$TMP/srv.log")" "GET /$gp "
    done
  else
    bad "http (local server): the server did not start" "$(cat "$TMP/srv.log")"
  fi
  kill_if TERM "$SRV" http.server
else
  printf 'skip: python3 is not installed, no local server test\n'
fi

# pr with the stub gh
RUN_ENV="STUB_GH=MERGED"
run pr 18 --interval 1 --timeout 30 --no-notify
eq "pr: a merged PR passes" "$RC" 0
RUN_ENV=
join r_to
eq "pr: an open PR times out" "$RC" 3
eq "pr: timeout last line" "$(lastline)" HUMAN_STEP_TIMEOUT

# cmd
touch "$W/flag"
run cmd "test -f $W/flag" --interval 1 --timeout 30 --no-notify
eq "cmd: exit 0 passes" "$RC" 0
rx "cmd: pass last line" "$(lastline)" '^HUMAN_STEP_DONE after [01]s$'
join c_to
eq "cmd: a failing command times out" "$RC" 3
eq "cmd: timeout last line" "$(lastline)" HUMAN_STEP_TIMEOUT

# pid
newdead
run pid "$DP" --interval 1 --timeout 30 --no-notify
eq "pid: an ended process passes" "$RC" 0
join p_to
eq "pid: a running process times out" "$RC" 3
eq "pid: timeout last line" "$(lastline)" HUMAN_STEP_TIMEOUT
run pid "00$SL" --timeout 1 --no-notify
eq "pid: a number with leading zeros is the same process" "$RC" 3
sh -c 'exit 0' & ZP=$!; sleep 1
run pid "$ZP" --interval 1 --timeout 30 --no-notify
eq "pid: a zombie (ended, not waited for) passes" "$RC" 0
wait "$ZP"

# ---------- case 2: a growing file, and unfinished downloads ----------
section "case 2: a growing file does not pass, an unfinished download never passes"
G=$TMP/w2; mkdir -p "$G"
grow() { # grow FILE: appends a line each second for 4 seconds
  ( i=0; while [ "$i" -lt 4 ]; do printf 'x\n' >> "$1"; i=$((i + 1)); sleep 1; done ) >/dev/null 2>&1 </dev/null &
  track $! sleep
}
D=$TMP/w2d; mkdir -p "$D/sub"
for f in a.crdownload b.part c.partial d.download e.tmp; do printf 'x\n' > "$D/$f"; done
grow "$G/a.dat"; grow "$G/b.dat"
par g_a file "$G/a.dat" --stable 2 --interval 1 --timeout 3 --no-notify
par g_b file "$G/b.dat" --stable 2 --interval 1 --timeout $((30 + LOOSE)) --no-notify
par d_a file "$D/*" --stable 1 --interval 1 --timeout 2 --no-notify
join g_a
eq "growing: no pass while it grows (stable 2, timeout 3)" "$RC" 3
join g_b
eq "growing: it passes when the file is stable" "$RC" 0
within "growing: it passes after the writer stopped (4 s of writes + 2 s)" "$DUR" 4 $((9 + LOOSE))
join d_a
eq "downloads: unfinished names and a folder never pass" "$RC" 3
printf 'real\n' > "$D/real.pdf"
run file "$D/*" --stable 1 --interval 1 --timeout 30 --no-notify
eq "downloads: a finished file passes" "$RC" 0

# ---------- case 3: pr with stub gh and glab ----------
section "case 3: pr with a stub CLI"
mkrepo
git remote add origin https://github.example.invalid/o/r.git
RUN_PATH=; reset_log
RUN_ENV="STUB_GH=MERGED"; run pr 18 --interval 1 --timeout 30 --no-notify
eq "gh: merged passes" "$RC" 0
has "gh: the command line" "$(cat "$STUB_LOG/gh.log")" "gh pr view 18 --json state --jq .state|GH_PROMPT_DISABLED=1"
RUN_ENV="STUB_GH=OPEN"; par g_open pr 18 --interval 1 --timeout 1 --no-notify
RUN_ENV="STUB_GH=OPEN"; par g_open_c pr 18 --state closed --interval 1 --timeout 1 --no-notify
RUN_ENV="STUB_GH=CLOSED"; par g_closed pr 18 --interval 1 --timeout 1 --no-notify
RUN_ENV="STUB_GH=CLOSED"; par g_closed_m pr 18 --state merged --interval 1 --timeout 1 --no-notify
RUN_ENV="STUB_GH=FAIL"; par g_fail pr 18 --interval 1 --timeout 1 --no-notify
RUN_ENV="STUB_GH=WEIRD"; par g_weird pr 18 --interval 1 --timeout 1 --no-notify
RUN_ENV="STUB_GH=CLOSED"; run pr 18 --state closed --interval 1 --timeout 30 --no-notify
eq "gh: closed passes with --state closed" "$RC" 0
RUN_ENV="STUB_GH=MERGED"; run pr 18 --state closed --interval 1 --timeout 30 --no-notify
eq "gh: merged passes with --state closed (the PR is not open)" "$RC" 0
for j in g_open g_open_c g_closed g_closed_m g_fail g_weird; do join $j; eq "gh: $j keeps waiting until the timeout" "$RC" 3; done

# glab with a gitlab origin, with jq and without jq
git remote set-url origin https://gitlab.example.invalid/g/p.git
for jqmode in jq nojq; do
  [ "$jqmode" = nojq ] && nj="REAL_NO_JQ=1" || nj=
  reset_log
  RUN_ENV="STUB_GLAB=merged $nj"; run pr 18 --interval 1 --timeout 30 --no-notify
  eq "glab ($jqmode): a gitlab origin and a merged MR passes" "$RC" 0
  has "glab ($jqmode): the command line" "$(cat "$STUB_LOG/glab.log")" "glab mr view 18 --output json"
  [ ! -e "$STUB_LOG/gh.log" ] && ok || bad "glab ($jqmode): gh was called for a gitlab origin"
  RUN_ENV="STUB_GLAB=closed $nj"; par l_closed pr 18 --interval 1 --timeout 1 --no-notify
  RUN_ENV="STUB_GLAB=opened $nj"; par l_open pr 18 --state closed --interval 1 --timeout 1 --no-notify
  RUN_ENV="STUB_GLAB=FAIL $nj"; par l_fail pr 18 --interval 1 --timeout 1 --no-notify
  RUN_ENV="STUB_GLAB=closed $nj"; run pr 18 --state closed --interval 1 --timeout 30 --no-notify
  eq "glab ($jqmode): closed passes for --state closed" "$RC" 0
  RUN_ENV="STUB_GLAB=merged STUB_GLAB_FIRST=1 $nj"; run pr 18 --interval 1 --timeout 30 --no-notify
  eq "glab ($jqmode): the state of the author object is not the state of the MR" "$RC" 0
  join l_closed; eq "glab ($jqmode): closed times out for --state merged" "$RC" 3
  join l_open; eq "glab ($jqmode): opened times out" "$RC" 3
  join l_fail; eq "glab ($jqmode): a CLI error keeps waiting until the timeout" "$RC" 3
done
# gh is missing: glab takes over, with a github origin
git remote set-url origin https://github.example.invalid/o/r.git
RUN_PATH=$FARM_GLAB; RUN_ENV="STUB_GLAB=merged"
reset_log; run pr 18 --interval 1 --timeout 30
eq "glab: used when gh is missing" "$RC" 0
# a gitlab origin, and only gh on the PATH: exit 2
git remote set-url origin https://gitlab.example.invalid/g/p.git
RUN_PATH=$FARM_GH; RUN_ENV="STUB_GH=MERGED"
reset_log; run pr 18 --interval 1 --timeout 5
eq "glab missing with a gitlab origin: exit 2" "$RC" 2
has "glab missing: the reason" "$ERR" "real-await: the CLI for pr is missing"
eq "glab missing: no notification" "$(nnotify)" 0
[ ! -e "$STUB_LOG/gh.log" ] && ok || bad "glab missing: gh was called"
# neither CLI on the PATH: exit 2
git remote set-url origin https://github.example.invalid/o/r.git
RUN_PATH=$FARM_NONE; RUN_ENV=
reset_log; run pr 18 --interval 1 --timeout 5
eq "no CLI on the PATH: exit 2" "$RC" 2
eq "no CLI on the PATH: nothing on stdout" "$OUT" ""
has "no CLI on the PATH: the reason" "$ERR" "real-await: the CLI for pr is missing"
eq "no CLI on the PATH: no notification" "$(nnotify)" 0
eq "no CLI on the PATH: no wait file" "$(nwait)" 0
RUN_PATH=; RUN_ENV=

# ---------- case 4: one notification ----------
section "case 4: the notification fires once"
mkrepo
PROJ=$(basename "$R")
for jqmode in jq nojq; do
  [ "$jqmode" = nojq ] && RUN_ENV="REAL_NO_JQ=1" || RUN_ENV=
  reset_log
  run cmd true --interval 1 --timeout 30
  eq "notify ($jqmode): the run passes" "$RC" 0
  eq "notify ($jqmode): exactly one call at the start" "$(nnotify)" 1
  has "notify ($jqmode): the title and the project" "$(cat "$STUB_LOG/notify.log")" "Waiting for you ($PROJ)"
  has "notify ($jqmode): the default message and the time" "$(cat "$STUB_LOG/notify.log")" "command true, times out in 30 s"
  reset_log
  run cmd false --interval 1 --timeout 2
  eq "notify ($jqmode): a timeout run: still one call, none at the end" "$(nnotify)" 1
  reset_log
  run cmd true --timeout 600
  has "notify ($jqmode): 600 s is 10 min" "$(cat "$STUB_LOG/notify.log")" "times out in 10 min"
  reset_log
  run cmd true --timeout 61
  has "notify ($jqmode): 61 s rounds up to 2 min" "$(cat "$STUB_LOG/notify.log")" "times out in 2 min"
  reset_log
  run cmd true --timeout 60
  has "notify ($jqmode): 60 s is 1 min" "$(cat "$STUB_LOG/notify.log")" "times out in 1 min"
  reset_log
  run cmd true --message 'Log in to the portal' --timeout 120
  has "notify ($jqmode): --message replaces the default" "$(cat "$STUB_LOG/notify.log")" "Log in to the portal, times out in 2 min"
  reset_log
  run cmd true --message '--dash first' --timeout 120
  has "notify ($jqmode): a message that starts with a dash loses it" "$(cat "$STUB_LOG/notify.log")" " dash first, times out"
  reset_log
  run cmd true --no-notify
  eq "notify ($jqmode): --no-notify gives no call" "$(nnotify)" 0
  reset_log
  run cmd true --timeout 0
  run nope
  run file
  eq "notify ($jqmode): bad input gives no call" "$(nnotify)" 0
done
RUN_ENV=
reset_log
run file '~/Downloads/x.pdf' --stable 1 --interval 1 --timeout 30
has "notify: the default file message" "$(cat "$STUB_LOG/notify.log")" "file ~/Downloads/x.pdf, times out in 30 s"
reset_log
RUN_ENV="STUB_GH=MERGED"; run pr 18 --interval 1
has "notify: the default PR message and the 30 min default" "$(cat "$STUB_LOG/notify.log")" "PR 18 merged, times out in 30 min"
RUN_ENV="STUB_GH=CLOSED"; reset_log; run pr 18 --state closed --interval 1
has "notify: the default PR message for --state closed" "$(cat "$STUB_LOG/notify.log")" "PR 18 closed, times out in 30 min"
RUN_ENV=; reset_log
newdead
run pid "$DP" --interval 1
has "notify: the default process message" "$(cat "$STUB_LOG/notify.log")" "process $DP, times out in 10 min"
reset_log
RUN_PATH="$TMP/curlstub:$PATH"; RUN_ENV="STUB_CODE=200"
run http "https://user:s3cretpw${AT}host.invalid/path?x=1" --interval 1
has "notify: the default URL message" "$(cat "$STUB_LOG/notify.log")" "URL https://***@host.invalid/path?x=1, times out in 10 min"
hasnt "notify: no password in the notification" "$(cat "$STUB_LOG/notify.log")" s3cretpw
RUN_PATH=; RUN_ENV=
reset_log
run cmd "$(rep a 80)" --interval 1 --timeout 1
has "notify: the default command message is the first 40 characters" "$(cat "$STUB_LOG/notify.log")" "command $(rep a 40), times out"
hasnt "notify: the command is cut" "$(cat "$STUB_LOG/notify.log")" "$(rep a 41)"
reset_log
run cmd true --message "$(rep b 300)"
hasnt "notify: a message is cut to 160 characters" "$(cat "$STUB_LOG/notify.log")" "$(rep b 161)"
has "notify: a long message keeps 160 characters" "$(cat "$STUB_LOG/notify.log")" "$(rep b 160)"

# ---------- case 5: exit codes and last lines ----------
section "case 5: exit codes and last lines"
par x_to cmd false --interval 1 --timeout 1 --no-notify
run cmd true --no-notify
eq "pass: exit 0" "$RC" 0
rx "pass: exact last line" "$(lastline)" '^HUMAN_STEP_DONE after [01]s$'
eq "pass: nothing on stderr" "$ERR" ""
join x_to
eq "timeout: exit 3" "$RC" 3
eq "timeout: exact last line" "$(lastline)" HUMAN_STEP_TIMEOUT
eq "timeout: nothing on stderr" "$ERR" ""
eq "a quiet wait: only one line on stdout" "$OUT" HUMAN_STEP_TIMEOUT
run cmd --no-notify
eq "bad input: exit 2" "$RC" 2
eq "bad input: no HUMAN_STEP line" "$OUT" ""
run cmd 'sleep 2; true' --interval 1 --timeout 30 --no-notify
rx "the last line of a pass" "$(lastline)" '^HUMAN_STEP_DONE after [0-9]+s$'
within "the time in the last line counts the seconds since the start" "$(lastline | sed 's/^HUMAN_STEP_DONE after \([0-9]*\)s$/\1/')" 2 "$DUR"

# ---------- case 6: secrets in the output of cmd ----------
section "case 6: a cmd that prints secrets"
mkrepo
reset_log
cmdtxt="echo $tok; echo token=hunter2secret; echo 'curl -H Bearer abcdef1234567890xyz'; echo plain >&2; false"
run cmd "$cmdtxt" --interval 1 --timeout 1
eq "secrets: timeout exit 3" "$RC" 3
eq "secrets: the last line" "$(lastline)" HUMAN_STEP_TIMEOUT
for s in "$tok" hunter2secret abcdef1234567890xyz; do
  hasnt "secrets: not in stdout ($s)" "$OUT" "$s"
  hasnt "secrets: not in stderr ($s)" "$ERR" "$s"
  hasnt "secrets: not in the notification ($s)" "$(cat "$STUB_LOG/notify.log")" "$s"
done
has "secrets: the token prefix stays" "$OUT" "ghp_***"
has "secrets: the key=value mask" "$OUT" "token=***"
has "secrets: the Bearer mask" "$OUT" "Bearer ***"
has "secrets: the output of stderr is shown too" "$OUT" plain
par t_to cmd 'i=1; while [ $i -le 8 ]; do echo l$i; i=$((i + 1)); done; false' --interval 1 --timeout 1 --no-notify
run cmd "echo $tok; true" --interval 1 --timeout 30 --no-notify
eq "secrets: pass exit 0" "$RC" 0
hasnt "secrets: not in stdout on a pass" "$OUT" "$tok"
has "secrets: masked on a pass" "$OUT" "ghp_***"
rx "secrets: the last line on a pass" "$(lastline)" '^HUMAN_STEP_DONE after [01]s$'
join t_to
eq "tail: 5 lines of output and the last line" "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" 6
eq "tail: the first line is line 4" "$(printf '%s\n' "$OUT" | sed -n 1p)" l4
hasnt "tail: line 3 is cut off" "$OUT" l3
run cmd 'echo l1; true' --no-notify
eq "tail: a short output is shown fully, before the last line" "$(printf '%s\n' "$OUT" | sed 's/after [0-9]*s$/after Ns/')" "l1
HUMAN_STEP_DONE after Ns"
run cmd "awk 'BEGIN { for (i = 0; i < 300; i++) printf \"a\"; print \"\" }'; true" --no-notify
eq "tail: a line is cut to 160 characters" "$(printf '%s\n' "$OUT" | sed -n 1p | awk '{ print length($0) }')" 160
run cmd 'printf "x\001y\033[31mz\n"; true' --no-notify
hasnt "tail: control characters are removed" "$OUT" "$(printf '\033')"
run file "$W/ready.txt" --stable 1 --interval 1 --timeout 30 --no-notify
eq "tail: only cmd prints the output of its tries" "$(printf '%s\n' "$OUT" | sed 's/after [0-9]*s$/after Ns/')" "HUMAN_STEP_DONE after Ns"
# the wait file is masked
bg "$TMP/o6" cmd "echo x; test -f $W/nothere" --message "deploy $tok" --interval 1 --timeout 60 --no-notify
p6=$BGPID
until_true $((5 + LOOSE)) nwait_is 1
wf=$(cat "$SD"/wait.* 2>/dev/null)
hasnt "secrets: not in the wait file" "$wf" "$tok"
has "secrets: the wait file has the mask" "$wf" "ghp_***"
kill_if TERM "$p6" real-await; waitend "$p6" $((5 + LOOSE))

# ---------- case 7: bad input ----------
section "case 7: bad input"
mkrepo
RUN_PATH="$TMP/curlstub:$PATH"; RUN_ENV=
bad_input() { # bad_input NAME ARGS. Exit 2, one line on stderr, nothing on stdout, no notification, no wait file, no network call.
  bn=$1; shift
  reset_log
  run "$@"
  eq "$bn: exit 2" "$RC" 2
  eq "$bn: nothing on stdout" "$OUT" ""
  eq "$bn: one line on stderr" "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" 1
  rx "$bn: the line starts with real-await:" "$ERR" '^real-await: .'
  eq "$bn: no notification" "$(nnotify)" 0
  eq "$bn: no wait file" "$(nwait)" 0
  [ ! -e "$STUB_LOG/curl.log" ] && ok || bad "$bn: curl was called"
  [ ! -e "$STUB_LOG/gh.log" ] && ok || bad "$bn: gh was called"
}
bad_input "no probe"
bad_input "unknown probe" nope
bad_input "an option as the probe" --timeout 5 file x
bad_input "file: no GLOB" file
bad_input "http: no URL" http
bad_input "pr: no NUMBER" pr
bad_input "cmd: no COMMAND" cmd
bad_input "pid: no PID" pid
bad_input "options only, no argument" file --timeout 5
bad_input "a second argument for file" file a b
bad_input "a second argument for cmd" cmd true false
bad_input "a second argument for pid" pid 1 2
bad_input "an unknown option" file x --nope
bad_input "the form --opt=VALUE" file x --timeout=5
bad_input "a lone dash" file x -z
bad_input "--timeout without a value" file x --timeout
bad_input "--interval without a value" cmd true --interval
bad_input "--message without a value" cmd true --message
bad_input "--stable without a value" file x --stable
bad_input "--status without a value" http http://a.invalid --status
bad_input "--contains without a value" http http://a.invalid --contains
bad_input "--state without a value" pr 5 --state
bad_input "--stable for cmd" cmd true --stable 3
bad_input "--stable for http" http http://a.invalid --stable 3
bad_input "--status for file" file x --status 200
bad_input "--status for pid" pid 5 --status 200
bad_input "--contains for file" file x --contains a
bad_input "--contains for cmd" cmd true --contains a
bad_input "--state for cmd" cmd true --state closed
bad_input "--state for http" http http://a.invalid --state closed
bad_input "--stable for pr" pr 5 --stable 1
for v in 0 abc 86401 -5 1.5 '' ' 5' '5 ' +5 99999999999999999999; do
  bad_input "--timeout '$v'" cmd true --timeout "$v"
done
bad_input "--interval 0" cmd true --interval 0
bad_input "--interval 86401" cmd true --interval 86401
bad_input "--interval abc" cmd true --interval abc
bad_input "--stable 0" file x --stable 0
bad_input "--stable 86401" file x --stable 86401
bad_input "--stable abc" file x --stable abc
for v in 99 600 abc 20 2000 '' 2x -200; do
  bad_input "--status '$v'" http http://a.invalid --status "$v"
done
bad_input "--contains empty" http http://a.invalid --contains ''
bad_input "--state open" pr 5 --state open
bad_input "--state MERGED" pr 5 --state MERGED
bad_input "URL without a scheme" http example.invalid/x
bad_input "URL with ftp" http ftp://example.invalid/x
bad_input "URL with no host" http http://
bad_input "URL with no host (https)" http https://
bad_input "URL with a space" http 'https://example.invalid/a b'
bad_input "URL with a tab" http "$(printf 'https://example.invalid/a\tb')"
bad_input "URL with a control character" http "$(printf 'https://example.invalid/a\001b')"
bad_input "URL with a newline" http 'https://example.invalid/a
b'
bad_input "URL, empty" http ''
bad_input "pr NUMBER abc" pr abc
bad_input "pr NUMBER 0" pr 0
bad_input "pr NUMBER 00" pr 00
bad_input "pr NUMBER with 11 digits" pr 12345678901
bad_input "pr NUMBER with a dot" pr 1.5
bad_input "pr NUMBER, empty" pr ''
bad_input "pid PID abc" pid abc
bad_input "pid PID 0" pid 0
bad_input "pid PID with 11 digits" pid 12345678901
bad_input "pid PID negative" pid -4
bad_input "pid PID, empty" pid ''
bad_input "cmd, empty" cmd ''
bad_input "file, empty" file ''
RUN_PATH=$FARM_NONE
bad_input "http when curl is missing" http http://example.invalid/
RUN_PATH="$TMP/curlstub:$PATH"
# the reason never holds a secret
bad_input "a secret in a URL" http "http://user:s3cretpw${AT}host.invalid/a b"
hasnt "a secret in a URL: not in the reason" "$ERR" s3cretpw
hasnt "a secret in a URL: no raw URL" "$ERR" host.invalid
bad_input "a secret in an unknown option" file x "--token=$tok"
hasnt "a secret in an unknown option: not in the reason" "$ERR" "$tok"
bad_input "a secret in a bad value" cmd true --timeout "$tok"
hasnt "a secret in a bad value: not in the reason" "$ERR" "$tok"
bad_input "a secret as the probe name" "$tok"
hasnt "a secret as the probe name: masked" "$ERR" "$tok"
RUN_PATH=; RUN_ENV=
# valid forms of the same options still pass: options before and after the argument
run --timeout 5 cmd true --no-notify
eq "options cannot come before the probe" "$RC" 2
run cmd --no-notify --timeout 30 true
eq "options can come before the argument" "$RC" 0
run cmd true --no-notify --timeout 007 --interval 001
eq "a number with leading zeros is the same number" "$RC" 0
run cmd true --no-notify --timeout 86400 --interval 86400
eq "86400 is allowed" "$RC" 0

# ---------- case 8: cleanup when the test stops the script ----------
section "case 8: cleanup after a signal"
mkrepo
W=$TMP/w8; mkdir -p "$W"
RUN_PATH=; RUN_ENV=
bg "$TMP/o8" cmd "sleep 60 & echo \$! > $W/child8; wait" --timeout 60 --interval 1 --no-notify
p8=$BGPID
bg "$TMP/o8h" cmd false --timeout 60 --interval 30 --no-notify
p8h=$BGPID
bg "$TMP/o8f" file "$W/nothere-*" --timeout 60 --interval 1 --no-notify
p8f=$BGPID
until_true $((5 + LOOSE)) nwait_is 3
eq "TERM: the wait files exist while the scripts wait" "$(nwait)" 3
eq "TERM: the wait file is named after the PID of the script" "$(ls "$SD" | grep -c "^wait\.$p8\$")" 1
until_true $((5 + LOOSE)) file_is "$W/child8"
c8=$(cat "$W/child8"); track "$c8" sleep
gone "$c8" && bad "TERM: the command child did not start" || ok
kill_if TERM "$p8" real-await
waitend "$p8" $((5 + LOOSE))
eq "TERM: exit 143" "$RC" 143
eq "TERM: the script ended in time" "$LATE" 0
gone "$c8" && ok || bad "TERM: the command child still runs"
eq "TERM: only its own wait file is gone" "$(nwait)" 2
eq "TERM: no HUMAN_STEP line" "$(grep -c HUMAN_STEP "$TMP/o8")" 0
# HUP while the script sleeps between two tries
sleep 1
kill_if HUP "$p8h" real-await
waitend "$p8h" $((4 + LOOSE))
eq "HUP: exit 129" "$RC" 129
eq "HUP: the sleep did not delay the end" "$LATE" 0
eq "HUP: its wait file is gone" "$(ls "$SD" | grep -c "^wait\.$p8h\$")" 0
# TERM to a script that waits for a file probe
kill_if TERM "$p8f" real-await
waitend "$p8f" $((4 + LOOSE))
eq "TERM on a file wait: exit 143" "$RC" 143
eq "TERM on a file wait: no wait file is left" "$(nwait)" 0
eq "the signals: no temp folder is left" "$(ntmp)" 0
# a normal end leaves no file and no folder
run cmd true --no-notify
eq "normal end: no wait file" "$(nwait)" 0
run cmd false --interval 1 --timeout 1 --no-notify
eq "timeout end: no wait file" "$(nwait)" 0
eq "timeout end: the temp folder is removed" "$(ntmp)" 0
# the wait file content
bg "$TMP/o8c" cmd 'false' --message 'ship it' --timeout 30 --interval 1 --no-notify
p8c=$BGPID
until_true $((5 + LOOSE)) nwait_is 1
rx "the wait file: <start> <deadline> <probe> <message>" "$(cat "$SD/wait.$p8c")" '^[0-9]+ [0-9]+ cmd ship it$'
wf=$(cat "$SD/wait.$p8c"); set -- $wf
eq "the wait file: the deadline is the start + the timeout" "$(( $2 - $1 ))" 30
kill_if TERM "$p8c" real-await; waitend "$p8c" $((4 + LOOSE))
# a wait that got KILL leaves its file: a new wait removes it
rm -f "$SD"/wait.*
bg "$TMP/o8k" cmd false --timeout 60 --interval 1 --no-notify
p8k=$BGPID
until_true $((5 + LOOSE)) nwait_is 1
kill_if KILL "$p8k" real-await
waitend "$p8k" $((4 + LOOSE))
eq "KILL: exit 137" "$RC" 137
eq "KILL: the wait file stays" "$(ls "$SD" | grep -c "^wait\.$p8k\$")" 1
rm -rf "$TMP"/tmp/real-await.* # the KILLed script could not remove its temp folder
run cmd true --no-notify
eq "KILL: a new wait removes the stale file" "$(ls "$SD" | grep -c "^wait\.$p8k\$")" 0
# the same by hand: dead PID, past deadline and PID 0 go; a live wait and other names stay
NOW=$(date +%s)
newdead; D8=$DP
sleeper; L8=$SLP
rs_write "$SD" "wait.$D8" "$NOW $((NOW + 3000)) cmd dead pid" "$R"
rs_write "$SD" "wait.$$" "$((NOW - 100)) $((NOW - 5)) cmd past deadline" "$R"
rs_write "$SD" "wait.0" "$NOW $((NOW + 3000)) cmd pid zero" "$R"
rs_write "$SD" "wait.$L8" "$NOW $((NOW + 3000)) cmd live entry" "$R"
rs_write "$SD" "wait.abc" "$NOW $((NOW + 3000)) cmd other name" "$R"
rs_write "$SD" "wait.12345678901" "1 2 cmd eleven digits" "$R"
rs_write "$SD" "waitx" "1 2 cmd other name" "$R"
run cmd true --no-notify
eq "stale: the run passes" "$RC" 0
eq "stale: the file of a dead PID is removed" "$(ls "$SD" | grep -c "^wait\.$D8\$")" 0
eq "stale: a file with a past deadline is removed" "$(ls "$SD" | grep -c "^wait\.$$\$")" 0
eq "stale: the file of PID 0 is removed" "$(ls "$SD" | grep -c '^wait\.0$')" 0
eq "stale: a live wait with a future deadline stays" "$(cat "$SD/wait.$L8")" "$NOW $((NOW + 3000)) cmd live entry"
eq "stale: a name that is not wait.<digits> stays" "$(ls "$SD" | grep -c '^wait\.abc$')" 1
eq "stale: a name with 11 digits stays" "$(ls "$SD" | grep -c '^wait\.12345678901$')" 1
eq "stale: another file stays" "$(ls "$SD" | grep -c '^waitx$')" 1
eq "stale: the files of the state folder stay" "$(ls "$SD" | grep -Ec '^(root|turn_start)$')" 2
rm -f "$SD"/wait.* "$SD/waitx"

# ---------- case 9: two waits in one repo ----------
section "case 9: two waits in parallel"
mkrepo
W=$TMP/w9; mkdir -p "$W"
bg "$TMP/o9a" cmd "test -f $W/A" --message 'first wait' --timeout 120 --interval 1 --no-notify
p9a=$BGPID
bg "$TMP/o9b" cmd "test -f $W/B" --message 'second wait' --timeout 120 --interval 1 --no-notify
p9b=$BGPID
until_true $((6 + LOOSE)) nwait_is 2
eq "two wait files" "$(nwait)" 2
eq "a file for each PID (first)" "$(ls "$SD" | grep -c "^wait\.$p9a\$")" 1
eq "a file for each PID (second)" "$(ls "$SD" | grep -c "^wait\.$p9b\$")" 1
has "the first file has its own text" "$(cat "$SD/wait.$p9a")" " cmd first wait"
has "the second file has its own text" "$(cat "$SD/wait.$p9b")" " cmd second wait"
srun
has "real-status shows the first wait" "$SOUT" "first wait"
has "real-status shows the second wait" "$SOUT" "second wait"
eq "real-status: one waiting line for both" "$(printf '%s\n' "$SOUT" | grep -c '^waiting:')" 1
touch "$W/A"
waitend "$p9a" $((6 + LOOSE))
eq "the first wait ends with its own result" "$RC" 0
rx "the first wait: its own last line" "$(tail -n 1 "$TMP/o9a")" '^HUMAN_STEP_DONE after [0-9]+s$'
eq "the first wait: its file is gone, the second stays" "$(nwait)" 1
gone "$p9b" && bad "the second wait ended with the first" || ok
srun
hasnt "real-status: the first wait is gone" "$SOUT" "first wait"
has "real-status: the second wait stays" "$SOUT" "second wait"
touch "$W/B"
waitend "$p9b" $((6 + LOOSE))
eq "the second wait ends with its own result" "$RC" 0
rx "the second wait: its own last line" "$(tail -n 1 "$TMP/o9b")" '^HUMAN_STEP_DONE after [0-9]+s$'
eq "no wait file is left" "$(nwait)" 0
eq "no temp folder is left" "$(ntmp)" 0
# one ends by a timeout, the other by a pass
bg "$TMP/o9c" cmd "test -f $W/C" --timeout 4 --interval 1 --no-notify
p9c=$BGPID
bg "$TMP/o9d" cmd "test -f $W/D" --timeout 120 --interval 1 --no-notify
p9d=$BGPID
until_true $((6 + LOOSE)) nwait_is 2
waitend "$p9c" $((8 + LOOSE))
eq "a timeout does not stop the other wait: exit 3" "$RC" 3
eq "a timeout does not stop the other wait: its file is gone, the other stays" "$(nwait)" 1
touch "$W/D"
waitend "$p9d" $((6 + LOOSE))
eq "the other wait still passes" "$RC" 0

# ---------- case 10: interval and timeout ----------
section "case 10: interval and timeout"
W=$TMP/w10; mkdir -p "$W"
rm -f "$W"/tries*
par i_a cmd "date +%s >> $W/tries-a; false" --interval 1 --timeout 3 --no-notify
par i_b cmd "date +%s >> $W/tries-b; false" --interval 2 --timeout 5 --no-notify
par i_c cmd "date +%s >> $W/tries-c; false" --interval 30 --timeout 2 --no-notify
par i_d cmd "date +%s >> $W/tries-d" --interval 30 --timeout 2 --no-notify
par i_e cmd "date +%s >> $W/tries-e; test \$(wc -l < $W/tries-e) -ge 3" --interval 1 --timeout 60 --no-notify
join i_a
eq "timeout 3: exit 3" "$RC" 3
within "timeout 3, interval 1: total time" "$DUR" 3 $((5 + LOOSE))
within "timeout 3, interval 1: number of tries" "$(nlines "$W/tries-a")" 2 4
join i_b
within "timeout 5, interval 2: total time" "$DUR" 5 $((7 + LOOSE))
within "timeout 5, interval 2: number of tries" "$(nlines "$W/tries-b")" 2 3
gaps=$(awk 'NR > 1 && $1 - p < 2 { bad++ } { p = $1 } END { print bad + 0 }' "$W/tries-b")
eq "interval 2: the tries are at least 2 s apart" "$gaps" 0
join i_c
within "interval 30, timeout 2: the sleep is cut to the deadline" "$DUR" 2 $((4 + LOOSE))
eq "interval 30, timeout 2: one try" "$(nlines "$W/tries-c")" 1
join i_d
within "a pass at the first try ends at once" "$DUR" 0 $((1 + LOOSE))
join i_e
eq "a pass at the third try: exit 0" "$RC" 0
within "a pass at the third try: time" "$DUR" 2 $((4 + LOOSE))

# ---------- case 11: the 10 s limit of one try ----------
section "case 11: a try that runs past 10 s is stopped"
W=$TMP/w11; mkdir -p "$W"
sleeper; SL=$SLP
par l_a cmd "sleep 30 & echo \$! > $W/child11; wait" --timeout 12 --interval 1 --no-notify
# a try that ignores TERM is killed after 1 s
par l_b cmd "trap '' TERM; sleep 30 & echo \$! > $W/child11b; while :; do sleep 1; done" --timeout 12 --interval 1 --no-notify
join l_a
eq "the long try: exit 3" "$RC" 3
eq "the long try: last line" "$(lastline)" HUMAN_STEP_TIMEOUT
within "the long try: stopped after 10 to 14 s" "$DUR" 10 $((14 + LOOSE))
c11=$(cat "$W/child11"); track "$c11" sleep
gone "$c11" && ok || bad "the long try: the child still runs"
gone "$SL" && bad "the long try: another process was stopped" || ok
join l_b
eq "a try that ignores TERM: exit 3" "$RC" 3
within "a try that ignores TERM: stopped in 10 to 14 s" "$DUR" 10 $((14 + LOOSE))
c11=$(cat "$W/child11b"); track "$c11" sleep
gone "$c11" && ok || bad "a try that ignores TERM: the child still runs"
eq "the long tries: no temp folder is left" "$(ntmp)" 0

# ---------- case 12: no network call except the http probe ----------
section "case 12: no network call except the probe URL"
mkrepo
W=$TMP/w12; mkdir -p "$W"; touch "$W/f12"
RUN_PATH="$TMP/curlstub:$PATH"; RUN_ENV="STUB_GH=MERGED STUB_GLAB=merged"
reset_log
git remote add origin https://github.example.invalid/o/r.git
run file "$W/f12" --stable 1 --interval 1 --timeout 30
eq "file: passes" "$RC" 0
run cmd true
eq "cmd: passes" "$RC" 0
newdead
run pid "$DP" --timeout 30
eq "pid: passes" "$RC" 0
run pr 18 --timeout 30
eq "pr (gh): passes" "$RC" 0
git remote set-url origin https://gitlab.example.invalid/g/p.git
run pr 18 --timeout 30
eq "pr (glab): passes" "$RC" 0
run cmd false --timeout 1 --interval 1
eq "a timeout run" "$RC" 3
[ ! -e "$STUB_LOG/curl.log" ] && ok || bad "curl was called by a probe that is not http" "$(cat "$STUB_LOG/curl.log")"
bad_input "bad input" file
[ ! -e "$STUB_LOG/curl.log" ] && ok || bad "curl was called after a bad input" "$(cat "$STUB_LOG/curl.log")"
run http 'http://stub.invalid/some/path?a=1' --timeout 30
eq "http: passes" "$RC" 0
eq "http: curl was called once for a pass at the first try" "$(nlines "$STUB_LOG/curl.log")" 1
rx "http: the arguments" "$(cat "$STUB_LOG/curl.log")" '^-q -s -g -o [^ ]+/body -w %\{http_code\} --max-time 10 -- http://stub\.invalid/some/path\?a=1$'
rm -f "$STUB_LOG/curl.log"
RUN_ENV="STUB_CODE=500"
run http 'http://stub.invalid/some/path' --timeout 3 --interval 1
eq "http: a 500 times out" "$RC" 3
within "http: curl was called for each try" "$(nlines "$STUB_LOG/curl.log")" 1 4
eq "http: every call has the probe URL only" "$(grep -c -e '-- http://stub.invalid/some/path$' "$STUB_LOG/curl.log")" "$(nlines "$STUB_LOG/curl.log")"
eq "http: no other URL in any call" "$(grep -Eo 'https?://' "$STUB_LOG/curl.log" | wc -l | tr -d ' ')" "$(nlines "$STUB_LOG/curl.log")"
rx "http: the time limit is the time left, 3 s or less" "$(sed -n 1p "$STUB_LOG/curl.log")" ' --max-time [1-3] '
RUN_PATH=; RUN_ENV=

# ---------- case 13: real-status shows the waiting line ----------
section "case 13: real-status and the waiting line"
mkrepo
W=$TMP/w13; mkdir -p "$W"
srun
hasnt "no wait: no waiting line" "$SOUT" "waiting:"
bg "$TMP/o13" cmd "test -f $W/flag" --message 'ship the build' --interval 1 --timeout 50 --no-notify
p13=$BGPID
until_true $((5 + LOOSE)) nwait_is 1
srun
rx "the waiting line" "$(printf '%s\n' "$SOUT" | grep '^waiting:')" '^waiting: ship the build \([0-9]+ (s|min) left\)$'
eq "the waiting line comes after the turn line" "$(printf '%s\n' "$SOUT" | grep -n '^waiting:' | cut -d: -f1)" "$(( $(printf '%s\n' "$SOUT" | grep -n '^turn:' | cut -d: -f1) + 1 ))"
[ "$(printf '%s\n' "$SOUT" | wc -l | tr -d ' ')" -le 8 ] && ok || bad "real-status prints more than 8 lines"
touch "$W/flag"
waitend "$p13" $((5 + LOOSE))
eq "the wait ends" "$RC" 0
srun
hasnt "no line after the wait ends" "$SOUT" "waiting:"
# stale files
NOW=$(date +%s)
newdead; DP2=$DP
rs_write "$SD" "wait.$DP2" "$NOW $((NOW + 3000)) cmd dead process" "$R"
rs_write "$SD" "wait.$$" "$((NOW - 100)) $((NOW - 5)) cmd expired wait" "$R"
rs_write "$SD" "wait.0" "$NOW $((NOW + 3000)) cmd forged entry" "$R"
srun
hasnt "a dead PID is skipped" "$SOUT" "dead process"
hasnt "a past deadline is skipped" "$SOUT" "expired wait"
hasnt "PID 0 is skipped" "$SOUT" "forged entry"
hasnt "no waiting line for stale files" "$SOUT" "waiting:"
rs_write "$SD" "wait.$$" "$NOW $((NOW + 3000)) cmd live one" "$R"
srun
rx "a live file shows" "$(printf '%s\n' "$SOUT" | grep '^waiting:')" '^waiting: live one \([0-9]+ min left\)$'
hasnt "the dead PID stays skipped" "$SOUT" "dead process"
# at most 3 entries
sleeper; S1=$SLP; sleeper; S2=$SLP; sleeper; S3=$SLP
rs_write "$SD" "wait.$S1" "$NOW $((NOW + 3000)) cmd entry two" "$R"
rs_write "$SD" "wait.$S2" "$NOW $((NOW + 3000)) cmd entry three" "$R"
rs_write "$SD" "wait.$S3" "$NOW $((NOW + 3000)) cmd entry four" "$R"
srun
wl=$(printf '%s\n' "$SOUT" | grep '^waiting:')
eq "at most 3 entries" "$(printf '%s\n' "$wl" | grep -o ' left)' | wc -l | tr -d ' ')" 3
eq "one waiting line" "$(printf '%s\n' "$SOUT" | grep -c '^waiting:')" 1
has "entries are separated by a semicolon" "$wl" "left); "
[ "$(printf '%s\n' "$SOUT" | wc -l | tr -d ' ')" -le 8 ] && ok || bad "real-status prints more than 8 lines with 3 entries"
# a secret in a hand-made file is masked, and a bad line is harmless
rm -f "$SD"/wait.*
rs_write "$SD" "wait.$$" "$NOW $((NOW + 3000)) cmd deploy with token=hunter2secret" "$R"
srun
hasnt "a secret in the wait file is masked" "$SOUT" hunter2secret
has "the mask shows" "$SOUT" "token=***"
rs_write "$SD" "wait.$$" "abc def" "$R"
srun
hasnt "a wait file with no numbers is skipped" "$SOUT" "waiting:"
rm -f "$SD"/wait.*
# no turn record in a new repo: the waiting line still shows
mkrepo
rm -f "$SD/turn_start"
rs_write "$SD" "wait.$$" "$NOW $((NOW + 3000)) cmd no record" "$R"
srun
has "no turn record: the turn line" "$SOUT" "turn: no record"
rx "no turn record: the waiting line" "$(printf '%s\n' "$SOUT" | grep '^waiting:')" '^waiting: no record \([0-9]+ min left\)$'
# a folder that another root owns is not read
printf '/some/other/root\n' > "$SD/root"
srun
hasnt "a state folder of another root gives no waiting line" "$SOUT" "waiting:"

echo
printf 'passed: %d, failed: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
