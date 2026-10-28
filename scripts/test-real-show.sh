#!/bin/sh
# Test scripts/real-show.sh in a temporary folder. POSIX sh. Needs python3 and curl.
# The script uses a temporary HOME, a temporary state folder and a stub "open" in PATH.
# It never opens a window, a browser or a screen, and it never calls the real "open".
# It stops only the servers and the sleep process that it started. Usage: sh scripts/test-real-show.sh
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
RS=$ROOT/scripts/real-show.sh
SH=$(command -v sh)

TMP=$(mktemp -d "${TMPDIR:-/tmp}/real-show-test.XXXXXX") || exit 1
TMP=$(cd "$TMP" && pwd -P)

SLEEP_PIDS=
kill_if() { # kill_if PID NEEDLE: signal PID only when it is alive and its command line holds NEEDLE
  case $1 in ''|*[!0-9]*) return 0 ;; esac
  kill -0 "$1" 2>/dev/null || return 0
  case $(ps -ww -p "$1" -o args= 2>/dev/null) in *"$2"*) kill "$1" 2>/dev/null ;; esac
  return 0
}
cleanup() {
  for f in "$TMP"/state/real/show/*; do
    [ -f "$f" ] && kill_if "$(sed -n 's/^pid=//p' "$f")" real-show-server
  done
  for p in $SLEEP_PIDS; do kill_if "$p" 'sleep 300'; done
  rm -rf "$TMP"
}
trap cleanup EXIT
trap 'exit 1' INT TERM

# Isolated environment
mkdir -p "$TMP/home" "$TMP/state" "$TMP/config" "$TMP/tmp" "$TMP/stub" "$TMP/stubfail"
export HOME="$TMP/home"
export XDG_STATE_HOME="$TMP/state"
export XDG_CONFIG_HOME="$TMP/config"
export TMPDIR="$TMP/tmp"
for v in $(env | sed -n 's/^\(REAL_[A-Za-z_]*\)=.*/\1/p'); do unset "$v"; done
ST=$XDG_STATE_HOME/real/show
LOG=$TMP/open.log

# Stub "open": it only writes its arguments to a log. A second stub fails.
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s"\n' "$LOG" > "$TMP/stub/open"
printf '#!/bin/sh\nexit 1\n' > "$TMP/stubfail/open"
chmod +x "$TMP/stub/open" "$TMP/stubfail/open"
PATH=$TMP/stub:$PATH
export PATH

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; [ -n "${2:-}" ] && printf '      %s\n' "$2"; return 0; }
section() { printf '== %s\n' "$1"; }
eq() { if [ "$2" = "$3" ]; then ok; else bad "$1" "expected '$3', got '$2'"; fi; }
has() { case $2 in *"$3"*) ok ;; *) bad "$1" "missing text: $3 | in: $2" ;; esac; }
hasnt() { case $2 in *"$3"*) bad "$1" "unexpected text: $3" ;; *) ok ;; esac; }
rx() { if printf '%s\n' "$2" | grep -Eq "$3"; then ok; else bad "$1" "no match for $3 in: $2"; fi; }

RC=0; OUT=; ERR=
run() { # run ARGS: runs real-show.sh. Sets RC, OUT and ERR.
  RC=0
  OUT=$("$SH" "$RS" "$@" 2>"$TMP/err") || RC=$?
  ERR=$(cat "$TMP/err")
}
runp() { # runp BINDIR ARGS: runs real-show.sh with PATH limited to BINDIR
  b=$1; shift; RC=0
  OUT=$(PATH=$b "$SH" "$RS" "$@" 2>"$TMP/err") || RC=$?
  ERR=$(cat "$TMP/err")
}

lines() { printf '%s\n' "$1" | wc -l | tr -d ' '; }
port_of() { printf '%s' "$1" | sed -n 's|^.*http://127\.0\.0\.1:\([0-9]*\)/.*$|\1|p' | head -n 1; }
url_of() { printf '%s' "$1" | sed -n 's|^.*](\(.*\))$|\1|p' | head -n 1; }
ent() { sed -n "s/^$2=//p" "$ST/$1"; }
entries() { ls "$ST" 2>/dev/null | wc -l | tr -d ' '; }
code() { curl --noproxy '*' -s -o /dev/null --max-time 5 -w '%{http_code}' "$1"; }
get() { curl --noproxy '*' -fsS --max-time 5 "$1" 2>/dev/null; }
alive() { # alive PID: the PID is alive and runs a real-show server
  kill -0 "$1" 2>/dev/null || return 1
  case $(ps -ww -p "$1" -o args= 2>/dev/null) in *real-show-server*) return 0 ;; esac
  return 1
}
mkhtml() { mkdir -p "$1"; printf '<!doctype html>\n<html><head><title>%s</title></head><body>x</body></html>\n' "$3" > "$1/$2"; }
only_link() { # only_link NAME: one stdout line and an empty stderr
  eq "$1: one stdout line" "$(lines "$OUT")" 1
  eq "$1: empty stderr" "$ERR" ""
}
leftover() { ps -eo args= | grep -F real-show-server | grep -F "$TMP"; }

# ---------- static ----------
section "static checks"
sh -n "$RS" 2>/dev/null && ok || bad "syntax: real-show.sh"
[ -x "$RS" ] && ok || bad "real-show.sh is not executable"
for t in python3 curl; do command -v "$t" >/dev/null 2>&1 && ok || bad "this test needs $t"; done

# ---------- 1. html serve ----------
section "html serve"
mkhtml "$TMP/s1" page.html Probe
run "$TMP/s1/page.html"
eq "html serve: exit 0" "$RC" 0
rx "html serve: link format" "$OUT" '^\[page\.html\]\(http://127\.0\.0\.1:[0-9]+/page\.html\)$'
only_link "html serve"
P1=$(port_of "$OUT")
[ "${P1:-0}" -gt 0 ] && ok || bad "html serve: the port is not a number above 0" "port=$P1"
has "html serve: curl gives the title" "$(get "$(url_of "$OUT")")" "<title>Probe</title>"
eq "state entry has pid, port and root" "$(cat "$ST/$P1")" "pid=$(ent "$P1" pid)
port=$P1
root=$TMP/s1"
case $(ls -ld "$ST") in drwx------*) ok ;; *) bad "the state folder is not mode 700" ;; esac
alive "$(ent "$P1" pid)" && ok || bad "the server pid is not alive"

# ---------- 2. html name with spaces ----------
section "html name with spaces"
mkhtml "$TMP/a b" "my page.html" Probe
run "$TMP/a b/my page.html"
eq "spaces: exit 0" "$RC" 0
rx "spaces: %20 in the URL, spaces in the label" "$OUT" '^\[my page\.html\]\(http://127\.0\.0\.1:[0-9]+/my%20page\.html\)$'
only_link "spaces"
has "spaces: curl gives the title" "$(get "$(url_of "$OUT")")" "<title>Probe</title>"

# ---------- 3. non-html file ----------
section "file link"
mkdir -p "$TMP/f"
printf 'hello\n' > "$TMP/f/a.txt"
n0=$(entries)
run "$TMP/f/a.txt"
eq "file: exit 0" "$RC" 0
eq "file: link" "$OUT" "[a.txt](file://$TMP/f/a.txt)"
only_link "file"
eq "file: no server entry is made" "$(entries)" "$n0"
cd "$TMP/f" && run a.txt && cd "$ROOT" || exit 1
eq "file: a relative path gives the absolute link" "$OUT" "[a.txt](file://$TMP/f/a.txt)"
printf 'x\n' > "$TMP/f/we ird [x] & #.txt"
run "$TMP/f/we ird [x] & #.txt"
eq "file: special bytes are encoded, the label escapes brackets" "$OUT" "[we ird \\[x\\] & #.txt](file://$TMP/f/we%20ird%20%5Bx%5D%20%26%20%23.txt)"
u8=$(printf 'caf\303\251.txt'); printf 'x\n' > "$TMP/f/$u8"
run "$TMP/f/$u8"
eq "file: non-ASCII bytes are encoded" "$OUT" "[$u8](file://$TMP/f/caf%C3%A9.txt)"
ln -s "$TMP/f/a.txt" "$TMP/f/link.txt"
run "$TMP/f/link.txt"
eq "file: a link to a file keeps the name" "$OUT" "[link.txt](file://$TMP/f/link.txt)"
nl=$(printf '\n_'); nl=${nl%_}
printf 'x\n' > "$TMP/f/a${nl}b.txt"
run "$TMP/f/a${nl}b.txt"
eq "file: a newline in the name gives exit 0" "$RC" 0
eq "file: a newline in the name gives one line, the label shows ?" "$OUT" "[a?b.txt](file://$TMP/f/a%0Ab.txt)"

# ---------- 4. folder ----------
section "folder link"
mkdir -p "$TMP/a b/sub dir"
run "$TMP/f"
eq "folder: link" "$OUT" "[f](file://$TMP/f)"
only_link "folder"
run "$TMP/a b/sub dir"
eq "folder with spaces: %20 in the URL" "$OUT" "[sub dir](file://$TMP/a%20b/sub%20dir)"
cd "$TMP/f" && run . && cd "$ROOT" || exit 1
eq "folder: a dot gives the folder name" "$OUT" "[f](file://$TMP/f)"

# ---------- 5. --serve on a non-html file ----------
section "serve a non-web file"
awk 'BEGIN { for (i = 0; i < 500; i++) print "line " i }' > "$TMP/f/big.txt"
run --serve "$TMP/f/big.txt"
eq "serve txt: exit 0" "$RC" 0
rx "serve txt: http link" "$OUT" '^\[big\.txt\]\(http://127\.0\.0\.1:[0-9]+/big\.txt\)$'
only_link "serve txt"
eq "serve txt: status 200 and the same size" "$(curl --noproxy '*' -s -o /dev/null -w '%{http_code} %{size_download}' "$(url_of "$OUT")")" "200 $(wc -c < "$TMP/f/big.txt" | tr -d ' ')"
run --serve "$TMP/f"
eq "serve a folder: exit 2" "$RC" 2

# ---------- 6 to 9. --open ----------
section "--open"
export REAL_SHOW_OS=Darwin
: > "$LOG"
run --open "$TMP/f"
eq "open Darwin folder: exit 0" "$RC" 0
eq "open Darwin folder: link only" "$OUT" "[f](file://$TMP/f)"
eq "open Darwin folder: stub got -g and the path" "$(cat "$LOG")" "-g $TMP/f"
: > "$LOG"
run --open "$TMP/f/a.txt"
eq "open Darwin file: exit 0" "$RC" 0
eq "open Darwin file: link only" "$OUT" "[a.txt](file://$TMP/f/a.txt)"
eq "open Darwin file: stub got -g and the path" "$(cat "$LOG")" "-g $TMP/f/a.txt"
: > "$LOG"
run --open --serve "$TMP/f/a.txt"
eq "open Darwin --serve file: exit 0" "$RC" 0
rx "open Darwin --serve file: http link only" "$OUT" '^\[a\.txt\]\(http://127\.0\.0\.1:[0-9]+/a\.txt\)$'
eq "open Darwin --serve file: one line" "$(lines "$OUT")" 1
eq "open Darwin --serve file: stub got -g and the file" "$(cat "$LOG")" "-g $TMP/f/a.txt"
: > "$LOG"
run --open "$TMP/s1/page.html"
eq "open Darwin html: exit 0" "$RC" 0
eq "open Darwin html: the stub is not called" "$(cat "$LOG")" ""
eq "open Darwin html: line 2 is the note" "$(printf '%s\n' "$OUT" | sed -n 2p)" "web page: link only"
eq "open Darwin html: two lines" "$(lines "$OUT")" 2
run --open --url https://example.invalid/a
eq "open Darwin --url: exit 0" "$RC" 0
eq "open Darwin --url: the stub is not called" "$(cat "$LOG")" ""
eq "open Darwin --url: line 2 is the note" "$(printf '%s\n' "$OUT" | sed -n 2p)" "web page: link only"
run "$TMP/f"
eq "no --open on Darwin: link only" "$OUT" "[f](file://$TMP/f)"
eq "no --open on Darwin: the stub is not called" "$(cat "$LOG")" ""
runp "$TMP/stubfail:$PATH" --open "$TMP/f"
eq "open fails: exit 4" "$RC" 4
has "open fails: stderr" "$ERR" "real-show: open failed"
export REAL_SHOW_OS=Linux
run --open "$TMP/f"
eq "open Linux folder: exit 0" "$RC" 0
eq "open Linux folder: the stub is not called" "$(cat "$LOG")" ""
eq "open Linux folder: line 2 is the note" "$(printf '%s\n' "$OUT" | sed -n 2p)" "not macOS: link only"
eq "open Linux folder: line 1 is the link" "$(printf '%s\n' "$OUT" | sed -n 1p)" "[f](file://$TMP/f)"
unset REAL_SHOW_OS

# ---------- 10. --url ----------
section "--url"
run --url 'https://example.invalid/a(b)'
eq "url: exit 0" "$RC" 0
eq "url: parentheses are encoded in the target" "$OUT" "[https://example.invalid/a(b)](https://example.invalid/a%28b%29)"
run --url 'http://example.invalid/[x]'
eq "url: brackets are escaped in the label" "$OUT" "[http://example.invalid/\\[x\\]](http://example.invalid/[x])"
for u in 'ftp://x' 'http://a b' 'javascript:x' 'http://' 'http:///x' 'https://x/"y' "http://x/'y" 'http://x/<y' 'http://x/>y' 'http://x/`y' 'http://x/
y'; do
  run --url "$u"; eq "url rejected: exit 2 for $u" "$RC" 2
done
has "url rejected: one line on stderr" "$ERR" "real-show: "

# ---------- 11. --title ----------
section "--title"
run --title Probe "$TMP/s1/page.html"
eq "title match: exit 0" "$RC" 0
mkhtml "$TMP/s11" page.html Real
run --title Wrong "$TMP/s11/page.html"
eq "title mismatch: exit 3" "$RC" 3
has "title mismatch: stderr" "$ERR" 'real-show: title mismatch: expected "Wrong", got "Real"'
eq "title mismatch: no output on stdout" "$OUT" ""
grep -l "root=$TMP/s11\$" "$ST"/* >/dev/null 2>&1 && bad "title mismatch: the entry is still there" || ok
leftover | grep -F "$TMP/s11" >/dev/null && bad "title mismatch: the server is still running" || ok
mkdir -p "$TMP/s11n"; printf '<p>no title</p>\n' > "$TMP/s11n/page.html"
run "$TMP/s11n/page.html"
eq "no title: the size check passes, exit 0" "$RC" 0
mkdir -p "$TMP/s11m"; printf '<title>  Two\n   words </title>\n' > "$TMP/s11m/page.html"
run --title "Two words" "$TMP/s11m/page.html"
eq "title: whitespace is collapsed on both sides" "$RC" 0
mkhtml "$TMP/s6" p.html Healthy
run "$TMP/s6/p.html"; P6=$(port_of "$OUT"); PID6=$(ent "$P6" pid)
run --title Healthy "$TMP/s6/p.html"
eq "title match on a running server: exit 0 and the same port" "$RC $(port_of "$OUT")" "0 $P6"
run --title Wrong "$TMP/s6/p.html"
eq "wrong title on a running server: exit 3" "$RC" 3
has "wrong title on a running server: stderr" "$ERR" 'real-show: title mismatch: expected "Wrong", got "Healthy"'
alive "$PID6" && ok || bad "wrong title: the server of an earlier call was stopped"
has "wrong title: the earlier link still answers" "$(get "http://127.0.0.1:$P6/p.html")" "<title>Healthy</title>"
[ -f "$ST/$P6" ] && ok || bad "wrong title: the entry of the running server is gone"
run "$TMP/s6/p.html"
eq "after a wrong title the next call reuses the port" "$RC $(port_of "$OUT")" "0 $P6"
run --stop "$P6"

# ---------- 12. a port that serves another page ----------
section "reuse check: another page on the port"
mkhtml "$TMP/ca" page.html A
mkhtml "$TMP/cb" page.html B
run "$TMP/ca/page.html"
PA=$(port_of "$OUT"); PIDA=$(ent "$PA" pid)
sed "s|^root=.*|root=$TMP/cb|" "$ST/$PA" > "$TMP/entry" && cat "$TMP/entry" > "$ST/$PA"
run "$TMP/cb/page.html"
eq "another page: exit 0" "$RC" 0
PB=$(port_of "$OUT")
[ -n "$PB" ] && [ "$PB" != "$PA" ] && ok || bad "another page: the server was reused" "PA=$PA PB=$PB"
has "another page: the new link serves title B" "$(get "$(url_of "$OUT")")" "<title>B</title>"
alive "$PIDA" && bad "another page: the old server still runs" || ok
[ -e "$ST/$PA" ] && bad "another page: the old entry is still there" || ok
curl --noproxy '*' -fsS --max-time 2 "http://127.0.0.1:$PA/" >/dev/null 2>&1 && bad "another page: the old port still answers" || ok

# ---------- 13. root refusal ----------
section "root refusal"
printf '<title>H</title>\n' > "$HOME/h.html"
run --root / "$TMP/s1/page.html"; eq "root /: exit 2" "$RC" 2
has "root /: one line on stderr" "$ERR" "real-show: refused root"
run --root "$HOME" "$HOME/h.html"; eq "root HOME: exit 2" "$RC" 2
run "$HOME/h.html"; eq "a file directly in HOME, no --root: exit 2" "$RC" 2
run --root "$TMP" "$TMP/s1/page.html"; eq "root that is a parent of HOME: exit 2" "$RC" 2
mkhtml "$TMP/e1" page.html Env
printf 'SECRET=1\n' > "$TMP/e1/.env"
run "$TMP/e1/page.html"; eq "folder with .env, no --root: exit 2" "$RC" 2
i=0
for n in .git .env.local id_rsa id_ed25519 x.pem x.key; do
  i=$((i + 1)); mkhtml "$TMP/sec$i" page.html S; : > "$TMP/sec$i/$n"
  run "$TMP/sec$i/page.html"; eq "folder with $n, no --root: exit 2" "$RC" 2
done
run --root "$TMP/e1" "$TMP/e1/page.html"
eq "folder with .env, explicit --root: exit 0" "$RC" 0
E1=$(dirname "$(url_of "$OUT")")
[ "$(code "$E1/.env")" != 200 ] && ok || bad "the server serves .env"
mkhtml "$TMP/o1" page.html O
run --root "$TMP/s1" "$TMP/o1/page.html"; eq "file outside --root: exit 2" "$RC" 2
run --root "$TMP/nothing" "$TMP/s1/page.html"; eq "--root that is not a folder: exit 2" "$RC" 2

# ---------- 14. what the server refuses ----------
section "server refusals"
mkdir -p "$TMP/sy/sub" "$TMP/outdir"
mkhtml "$TMP/sy" page.html Sy
printf 'ok\n' > "$TMP/sy/ok.txt"; printf 'secret\n' > "$TMP/outside.txt"; printf 'secret\n' > "$TMP/outdir/f.txt"
printf 'x\n' > "$TMP/sy/.hidden"; printf 'x\n' > "$TMP/sy/key.pem"; printf 'x\n' > "$TMP/sy/id_rsa"; printf 'x\n' > "$TMP/sy/x.key"
ln -s "$TMP/outside.txt" "$TMP/sy/link.txt"; ln -s "$TMP/outdir" "$TMP/sy/dirlink"
run --root "$TMP/sy" "$TMP/sy/page.html"
eq "refusals: server started, exit 0" "$RC" 0
SY=$(dirname "$(url_of "$OUT")")
eq "refusals: a normal file is served" "$(code "$SY/ok.txt")" 200
for p in link.txt dirlink/f.txt .hidden key.pem id_rsa x.key sub/ ''; do
  [ "$(code "$SY/$p")" != 200 ] && ok || bad "refusals: the server serves /$p"
done
[ "$(curl --noproxy '*' --path-as-is -s -o /dev/null --max-time 5 -w '%{http_code}' "$SY/../outside.txt")" != 200 ] && ok || bad "refusals: a .. path leaves the root"
[ "$(code "$SY/%2e%2e/outside.txt")" != 200 ] && ok || bad "refusals: an encoded .. path leaves the root"
run --root "$TMP/sy" --serve "$TMP/sy/link.txt"
eq "a file link that points out of the root: exit 2" "$RC" 2

# ---------- 15. bad input ----------
section "bad input"
run; eq "no argument: exit 2" "$RC" 2
has "no argument: usage on stderr" "$ERR" "real-show: no PATH"
run "$TMP/nothing.txt"; eq "missing file: exit 2" "$RC" 2
run --nope; eq "unknown flag: exit 2" "$RC" 2
run --title; eq "--title without a value: exit 2" "$RC" 2
run --root; eq "--root without a value: exit 2" "$RC" 2
run --url; eq "--url without a value: exit 2" "$RC" 2
run "$TMP/f" "$TMP/f/a.txt"; eq "two paths: exit 2" "$RC" 2
run --list "$TMP/f"; eq "--list with a path: exit 2" "$RC" 2

# ---------- 16. --list ----------
section "--list"
run --stop all
mkhtml "$TMP/l1" page.html L1; mkhtml "$TMP/l2" page.html L2
run "$TMP/l1/page.html"; LA=$(port_of "$OUT"); LAP=$(ent "$LA" pid)
run "$TMP/l2/page.html"; LB=$(port_of "$OUT"); LBP=$(ent "$LB" pid)
want=$(printf '%s\n%s\n' "$LA $LAP $TMP/l1" "$LB $LBP $TMP/l2" | sort -n)
run --list
eq "list: PORT PID ROOT for each live server" "$OUT" "$want"
sh -c 'exit 0' & DEAD=$!; wait "$DEAD"
printf 'pid=%s\nport=4101\nroot=%s\n' "$DEAD" "$TMP/gone" > "$ST/4101"
run --list
eq "list: a dead entry is not shown" "$OUT" "$want"
[ -e "$ST/4101" ] && bad "list: the dead entry file is still there" || ok
eq "list: exit 0" "$RC" 0

# ---------- 17. --stop ----------
section "--stop"
run --stop "$LA"
eq "stop PORT: exit 0" "$RC" 0
eq "stop PORT: output" "$OUT" "stopped $LA"
alive "$LAP" && bad "stop PORT: the pid is still alive" || ok
curl --noproxy '*' -fsS --max-time 2 "http://127.0.0.1:$LA/" >/dev/null 2>&1 && bad "stop PORT: the port still answers" || ok
[ -e "$ST/$LA" ] && bad "stop PORT: the entry is still there" || ok
alive "$LBP" && ok || bad "stop PORT: another server was stopped"
mkhtml "$TMP/l3" page.html L3
run "$TMP/l3/page.html"; LC=$(port_of "$OUT"); LCP=$(ent "$LC" pid)
run --stop all
eq "stop all: exit 0" "$RC" 0
eq "stop all: one line for each server" "$OUT" "$(printf 'stopped %s\nstopped %s\n' "$LB" "$LC" | sort -k2,2n)"
for pp in "$LBP" "$LCP"; do alive "$pp" && bad "stop all: pid $pp is still alive" || ok; done
eq "stop all: no entry is left" "$(entries)" 0
run --stop 1
eq "stop 1: exit 2" "$RC" 2
has "stop 1: stderr" "$ERR" "real-show: no server from real-show on port 1"
run --stop abc; eq "stop abc: exit 2" "$RC" 2
run --stop
eq "bare --stop with no server: exit 0 and no output" "$RC$OUT" "0"

# ---------- 18. --stop refuses a PID that is not a server ----------
section "--stop refusal"
sleep 300 >/dev/null 2>&1 </dev/null &
SPID=$!
SLEEP_PIDS="$SLEEP_PIDS $SPID"
FP=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
mkdir -p "$ST"
printf 'pid=%s\nport=%s\nroot=%s\n' "$SPID" "$FP" "$TMP/none" > "$ST/$FP"
run --stop "$FP"
eq "refusal: exit 0" "$RC" 0
has "refusal: stderr" "$ERR" "real-show: refused to stop pid $SPID on port $FP: not a real-show server"
eq "refusal: nothing on stdout" "$OUT" ""
kill -0 "$SPID" 2>/dev/null && ok || bad "refusal: the sleep process was killed"
[ -e "$ST/$FP" ] && bad "refusal: the entry is still there" || ok
# the same entry in a list and in a bare --stop: the sleep survives too
printf 'pid=%s\nport=%s\nroot=%s\n' "$SPID" "$FP" "$TMP/none" > "$ST/$FP"
run --list
eq "refusal: --list drops it and prints nothing" "$OUT" ""
kill -0 "$SPID" 2>/dev/null && ok || bad "refusal: --list killed the sleep process"
printf 'pid=%s\nport=%s\nroot=%s\n' "$SPID" "$FP" "$TMP/none" > "$ST/$FP"
run --stop all
eq "refusal: --stop all exit 0" "$RC" 0
has "refusal: --stop all names the refusal" "$ERR" "refused to stop pid $SPID"
kill -0 "$SPID" 2>/dev/null && ok || bad "refusal: --stop all killed the sleep process"
printf 'pid=-1\nport=%s\nroot=%s\n' "$FP" "$TMP/none" > "$ST/$FP"
run --stop "$FP"
eq "refusal: a bad pid value is refused, exit 0" "$RC" 0
has "refusal: a bad pid value, stderr" "$ERR" "refused"

# ---------- 19. reuse ----------
section "reuse"
mkhtml "$TMP/r1" one.html One
mkhtml "$TMP/r1" two.html Two
run "$TMP/r1/one.html"; R1=$(port_of "$OUT")
run "$TMP/r1/two.html"; R2=$(port_of "$OUT")
eq "reuse: the same port for the second file" "$R2" "$R1"
eq "reuse: one entry in the state folder" "$(entries)" 1
has "reuse: the second file is served" "$(get "$(url_of "$OUT")")" "<title>Two</title>"
run --stop all

# ---------- 20. stale replacement ----------
section "stale entry"
mkhtml "$TMP/st" page.html Stale
printf 'pid=%s\nport=4102\nroot=%s\n' "$DEAD" "$TMP/st" > "$ST/4102"
run "$TMP/st/page.html"
eq "stale: exit 0" "$RC" 0
rx "stale: a new server answers" "$OUT" '^\[page\.html\]\(http://127\.0\.0\.1:[0-9]+/page\.html\)$'
[ -e "$ST/4102" ] && bad "stale: the stale entry is still there" || ok
eq "stale: one live entry" "$(entries)" 1
run --stop all

# ---------- 21. missing tools ----------
section "missing tools"
NEED='sed awk od tr grep ls find head sort dirname basename readlink mkdir chmod rm cat date sleep wc ps nohup uname env'
mkbin() { # mkbin DIR TOOL...: link the external tools into DIR
  mkdir -p "$1"; d=$1; shift
  for t in "$@"; do p=$(command -v "$t") || continue; case $p in /*) ln -s "$p" "$d/$t" ;; esac; done
}
mkbin "$TMP/bin-all" $NEED python3 curl
mkbin "$TMP/bin-nopy" $NEED curl
mkbin "$TMP/bin-nocurl" $NEED python3
mkhtml "$TMP/m1" page.html M
runp "$TMP/bin-all" "$TMP/m1/page.html"
eq "limited PATH with both tools: exit 0" "$RC" 0
runp "$TMP/bin-all" --stop all
runp "$TMP/bin-nopy" "$TMP/m1/page.html"
eq "python3 missing: html serve exit 4" "$RC" 4
has "python3 missing: stderr" "$ERR" "real-show: python3 not found"
runp "$TMP/bin-nopy" "$TMP/f/a.txt"
eq "python3 missing: a file link still works" "$OUT" "[a.txt](file://$TMP/f/a.txt)"
runp "$TMP/bin-nopy" "$TMP/f"
eq "python3 missing: a folder link still works" "$OUT" "[f](file://$TMP/f)"
runp "$TMP/bin-nocurl" "$TMP/m1/page.html"
eq "curl missing: html serve exit 4" "$RC" 4
has "curl missing: stderr" "$ERR" "real-show: curl not found"
runp "$TMP/bin-nocurl" "$TMP/f/a.txt"
eq "curl missing: a file link still works" "$OUT" "[a.txt](file://$TMP/f/a.txt)"
eq "tools missing: no server was started" "$(entries)" 0

# ---------- 23. exit codes ----------
section "exit codes"
run "$TMP/f"; eq "exit code 0 (ok)" "$RC" 0
run --nope; eq "exit code 2 (bad input)" "$RC" 2
run --title Wrong "$TMP/s11/page.html"; eq "exit code 3 (title mismatch)" "$RC" 3
runp "$TMP/bin-nopy" "$TMP/m1/page.html"; eq "exit code 4 (helper missing)" "$RC" 4

# ---------- cleanup ----------
section "cleanup"
run --stop all
eq "stop all at the end: exit 0" "$RC" 0
eq "no entry is left" "$(entries)" 0
leftover >/dev/null && bad "a real-show-server process of this test is still running" || ok

echo
printf 'passed: %d, failed: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
