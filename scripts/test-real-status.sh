#!/bin/sh
# Test scripts/real-status.sh in temporary repos. POSIX sh. Needs git. jq is optional (the evidence test runs without jq too).
# The script uses a temporary HOME, a temporary state folder and an empty git config.
# It does not touch your files or your git config. It removes only the temporary folder that it made.
# Usage: sh scripts/test-real-status.sh
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
RS=$ROOT/scripts/real-status.sh
SH=$(command -v sh)

TMP=$(mktemp -d "${TMPDIR:-/tmp}/real-status-test.XXXXXX") || exit 1
TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT INT TERM

# Isolated environment
mkdir -p "$TMP/home" "$TMP/state" "$TMP/config" "$TMP/tmp"
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

. "$ROOT/hooks/claude/real-state-lib.sh"

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; [ -n "${2:-}" ] && printf '      %s\n' "$2"; return 0; }
section() { printf '== %s\n' "$1"; }
eq() { if [ "$2" = "$3" ]; then ok; else bad "$1" "expected '$3', got '$2'"; fi; }
has() { case $2 in *"$3"*) ok ;; *) bad "$1" "missing text: $3 | in: $2" ;; esac; }
hasnt() { case $2 in *"$3"*) bad "$1" "unexpected text: $3 | in: $2" ;; *) ok ;; esac; }
rx() { if printf '%s\n' "$2" | grep -Eq "$3"; then ok; else bad "$1" "no match for $3 in: $2"; fi; }

RC=0; OUT=; ERR=
run() { # run [ARGS]. Runs real-status.sh. Sets RC, OUT and ERR. Every run must print 8 lines or less and finish in 2 s.
  s0=$(date +%s)
  RC=0
  OUT=$("$SH" "$RS" "$@" 2>"$TMP/err") || RC=$?
  ERR=$(cat "$TMP/err")
  s1=$(date +%s)
  nl=$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')
  if [ "$nl" -le 8 ]; then ok; else bad "more than 8 lines: $nl"; fi
  if [ $((s1 - s0)) -le 2 ]; then ok; else bad "the run took more than 2 seconds"; fi
}
line() { printf '%s\n' "$OUT" | sed -n "$1p"; } # line N of the output
lines() { printf '%s\n' "$OUT" | wc -l | tr -d ' '; }
rep() { awk -v c="$1" -v n="$2" 'BEGIN { for (i = 0; i < n; i++) printf "%s", c }'; }

n=0
mkrepo() { # sets R (the physical path) and SD (its state folder). One commit on main.
  n=$((n + 1)); R=$TMP/repo$n
  git init -q -b main "$R"
  git -C "$R" commit -q --allow-empty -m init
  R=$(cd "$R" && pwd -P)
  SD=$(rs_dir "$R")
}
state() { rs_write "$SD" "$1" "$2" "$R"; } # state NAME VALUE
now() { date +%s; }
ago() { printf '%s\n' $(( $(now) - $1 )); }
tok=ghp_$(rep a 30)
mb2=$(printf '\303\251') # a 2-byte character, built from octal bytes
ESC=$(printf '\033')

# ---------- usage ----------
section "usage"
RC=0; OUT=$("$SH" "$RS" --help 2>&1) || RC=$?
eq "--help exits 0" "$RC" 0
has "--help prints the usage" "$OUT" "Usage:"
run --nope
eq "an unknown flag exits 2" "$RC" 2
eq "an unknown flag prints nothing on stdout" "$OUT" ""
has "an unknown flag prints the usage on stderr" "$ERR" "Usage:"
mkrepo
run "$R" "$R"
eq "two folders exit 2" "$RC" 2

# ---------- git line ----------
section "git line"
mkrepo
run "$R"
eq "exit 0" "$RC" 0
rx "branch, no change, commit age" "$(line 1)" '^main  0 changed, last commit [0-9]+ s ago$'
printf 'x\n' > "$R/a.txt"; printf 'y\n' > "$R/b.txt"
run "$R"
has "untracked files count as changed" "$(line 1)" "2 changed"
git -C "$R" add a.txt b.txt
GIT_COMMITTER_DATE="$(ago 300) +0000" git -C "$R" commit -q -m two
run "$R"
eq "a commit 5 minutes old" "$(line 1)" "main  0 changed, last commit 5 min ago"
GIT_COMMITTER_DATE="$(ago 7300) +0000" git -C "$R" commit -q --allow-empty -m old
run "$R"
eq "a commit 2 hours old" "$(line 1)" "main  0 changed, last commit 2 h ago"
GIT_COMMITTER_DATE="$(ago 260000) +0000" git -C "$R" commit -q --allow-empty -m older
run "$R"
eq "a commit 3 days old" "$(line 1)" "main  0 changed, last commit 3 d ago"
git -C "$R" checkout -q --detach
run "$R"
rx "a detached HEAD shows the short hash" "$(line 1)" '^[0-9a-f]{7,}  0 changed, last commit '
git -C "$R" checkout -q main
run "$R/.git"
has "a folder inside the git folder does not fail" "$OUT" "git"
mkdir -p "$R/sub/dir"
run "$R/sub/dir"
has "a sub folder shows the repo" "$(line 1)" "main  0 changed"
n=$((n + 1)); R=$TMP/repo$n; git init -q -b main "$R"
run "$R"
eq "a repo with no commit" "$(line 1)" "main  0 changed, no commits"
mkdir "$TMP/plain"
run "$TMP/plain"
eq "outside git: exit 0" "$RC" 0
eq "outside git: the clear message" "$(line 1)" "git: not a git repo ($TMP/plain)"
eq "outside git: no contract" "$(line 2)" "contract: none"
eq "outside git: no record" "$(line 3)" "turn: no record"
cd "$TMP/plain" && run && cd "$ROOT"
eq "the default folder is the current folder" "$(line 1)" "git: not a git repo ($TMP/plain)"
run "$TMP/does-not-exist"
eq "a missing folder exits 2" "$RC" 2
eq "a missing folder prints nothing on stdout" "$OUT" ""
eq "a missing folder is named on stderr" "$ERR" "real-status: no such folder: $TMP/does-not-exist"
: > "$TMP/afile"
run "$TMP/afile"
eq "a file is not a folder: exit 2" "$RC" 2

# ---------- contract, claims and evidence (with and without jq) ----------
for m in "" 1; do
  label=jq; [ -n "$m" ] && label=no-jq
  export REAL_NO_JQ=$m
  section "contract and evidence ($label)"
  mkrepo
  run "$R"
  eq "no contract" "$(line 2)" "contract: none"
  eq "no evidence file: no last line" "$(lines)" 3
  mkdir -p "$R/.real"
  cat > "$R/.real/contract.md" <<'EOF'
Task: demo task
Status: Active

## OBJECTIVE
- not a done item

## DONE WHEN
- 1. the unit tests pass
- [ ] the page loads <!-- note -->
* the `lint` is clean
- <placeholder line>

## SCOPE
- src/**
EOF
  run "$R"
  eq "a contract with no claims" "$(line 2)" "contract: demo task (active), 0 of 3 items verified"
  printf '{"id":"e1","time":"t","exit":0,"hash":"h","command":"echo one"}\n{"id":"e2","time":"t","exit":0,"hash":"h","command":"echo two"}\n{"id":"e3","time":"t","exit":1,"hash":"h","command":"npm test"}\n{"id":"e4","time":"t","exit":"unknown","hash":"h","command":"make"}\n' > "$R/.real/evidence.jsonl"
  printf '1 | done | e1 | ok\n2 | done | e3 | the tests failed\n3 | done | e2, e4 | ok\n' > "$R/.real/claims.md"
  run "$R"
  eq "2 of 3 items verified (one item cites a failing id)" "$(line 2)" "contract: demo task (active), 2 of 3 items verified"
  eq "the last 3 commands with exit codes" "$(line 3)" "last: echo two (exit 0), npm test (1), make (unknown)"
  printf '1 | done | e1 | ok\n2 | done | e9 | an id that is not in the log\n3 | done | | no id\n' > "$R/.real/claims.md"
  run "$R"
  eq "an unknown id and a missing id do not verify" "$(line 2)" "contract: demo task (active), 1 of 3 items verified"
  printf '1 | done | e1 | ok\n2 | could-not-measure | | verifier: the user\n3 | maybe | e1 | x\n' > "$R/.real/claims.md"
  run "$R"
  eq "could-not-measure and an unknown status do not verify" "$(line 2)" "contract: demo task (active), 1 of 3 items verified"
  printf '1 | done | e1 | ok\n2 | done | e2 | ok\n3 | done | e1,e4 | ok\n' > "$R/.real/claims.md"
  run "$R"
  eq "all items verified" "$(line 2)" "contract: demo task (active), 3 of 3 items verified"
  rm -f "$R/.real/claims.md" "$R/.real/evidence.jsonl"
  run "$R"
  eq "no claims file and no evidence file" "$(line 2)" "contract: demo task (active), 0 of 3 items verified"
  printf 'Task: empty\nStatus: draft\n' > "$R/.real/contract.md"
  run "$R"
  eq "a contract with no DONE WHEN item" "$(line 2)" "contract: empty (draft), 0 of 0 items verified"

  section "secrets and special characters ($label)"
  mkrepo
  mkdir -p "$R/.real"
  printf 'Task: t\nStatus: active\n\n## DONE WHEN\n- a\n' > "$R/.real/contract.md"
  long=$(rep z 60)
  printf '{"id":"e1","time":"t","exit":0,"hash":"h","command":"curl -H \\"Authorization: Bearer %s\\" token=%s %s"}\n{"id":"e2","time":"t","exit":2,"hash":"h","command":"%s"}\n' "$(rep Q 12)" "$tok" "$tok" "$long" > "$R/.real/evidence.jsonl"
  run "$R"
  hasnt "a token in an evidence command is masked" "$OUT" "$tok"
  hasnt "a bearer value is masked" "$OUT" "$(rep Q 12)"
  has "the masked command stays readable" "$(line 3)" "curl -H"
  eq "a command is cut to 40 characters" "$(line 3 | sed 's/.*, //')" "$(rep z 40) (2)"
  printf '{"id":"e1","time":"t","exit":0,"hash":"h","command":"echo \\"hi\\" \\\\ done"}\n' > "$R/.real/evidence.jsonl"
  run "$R"
  eq "JSON escapes are read" "$(line 3)" 'last: echo "hi" \ done (exit 0)'
  glt=glpat-$(rep g 24); stt=sk_live_$(rep s 24) # built at run time, so the file holds no text that the pre-push scan blocks
  printf '{"id":"e1","time":"t","exit":0,"hash":"h","command":"deploy %s %s"}\n' "$glt" "$stt" > "$R/.real/evidence.jsonl"
  run "$R"
  eq "a GitLab token and a Stripe key in an evidence command are masked" "$(line 3)" "last: deploy glpat-*** sk_live_*** (exit 0)"
  printf 'not json at all\n{"broken\n' > "$R/.real/evidence.jsonl"
  run "$R"
  eq "a corrupt evidence file does not fail" "$RC" 0
  for bad in 'NOT JSON' '5'; do
    printf '{"id":"e1","time":"t","exit":0,"hash":"h","command":"curl x"}\n%s\n{"id":"e2","time":"t","exit":0,"hash":"h","command":"npm test"}\n' "$bad" > "$R/.real/evidence.jsonl"
    run "$R"
    eq "a bad middle line ($bad) is skipped and both valid commands show" "$(line 3)" "last: curl x (exit 0), npm test (0)"
  done
  rm -f "$R/.real/evidence.jsonl"

  state turn_start "$(ago 100)"
  printf 'fix the login %s now\n' "$tok" > "$SD/last_request"
  run "$R"
  hasnt "a token in last_request is masked" "$OUT" "$tok"
  has "the request is in the turn line" "$OUT" 'fix the login ghp_*** now'
  printf 'req %s[31mred%s[0m\n' "$ESC" "$ESC" > "$SD/last_request"
  state jobs "bash: dev server $ESC[1mbold"
  run "$R"
  hasnt "an escape sequence does not reach the output" "$OUT" "$ESC"
  has "the text around the escape stays" "$OUT" "red"
  printf '%s %s\n' "$(rep y 200)" tail > "$SD/last_request"
  run "$R"
  eq "a line is cut to 160 characters" "$(line 3 | wc -c | tr -d ' ')" 161
  state turn_start "$(ago 90)"
  printf '%s\n' "$(rep "$mb2" 200)" > "$SD/last_request"
  run "$R"
  pre='turn: running for 1 min - "'
  eq "a line is cut to 160 characters, not to 160 bytes" "$(line 3)" "$pre$(rep "$mb2" $((160 - ${#pre})))"
done
unset REAL_NO_JQ

# ---------- turn and jobs ----------
section "turn line"
mkrepo
run "$R"
eq "a missing state folder" "$(line 3)" "turn: no record"
eq "no jobs line without a record" "$(lines)" 3
state turn_start "$(ago 400)"
state last_request "write the report"
run "$R"
eq "a running turn" "$(line 3)" 'turn: running for 6 min - "write the report"'
state turn_end "$(ago 1000)"
run "$R"
eq "turn_end older than turn_start: the turn runs" "$(line 3)" 'turn: running for 6 min - "write the report"'
state turn_end "$(ago 120)"
run "$R"
eq "a stopped turn with no STATE line" "$(line 3)" 'turn: ended 2 min ago - "write the report"'
state state "blocked - log in at the site"
run "$R"
eq "a stopped turn with a state" "$(line 3)" 'turn: blocked - log in at the site 2 min ago - "write the report"'
state state done
state turn_end "$(ago 30)"
run "$R"
eq "a stopped turn of the state done" "$(line 3)" 'turn: done 30 s ago - "write the report"'
printf 'abc\n' > "$SD/turn_end"
run "$R"
eq "a corrupt turn_end counts as missing" "$(line 3)" 'turn: running for 6 min - "write the report"'
printf '12x\n' > "$SD/turn_start"
run "$R"
eq "two corrupt numbers: no record" "$(line 3)" "turn: no record"
printf '\n' > "$SD/turn_end"; : > "$SD/turn_start"
run "$R"
eq "empty files count as missing" "$(line 3)" "turn: no record"
printf '%s\n' 99999999999999999999999 > "$SD/turn_start"
run "$R"
eq "a number that is too long counts as missing" "$(line 3)" "turn: no record"
state turn_start "$(ago 90)"
printf 'other-root\n' > "$SD/root"
run "$R"
eq "a state folder of another root is not shown" "$(line 3)" "turn: no record"
printf '%s\n' "$R" > "$SD/root"
run "$R"
has "the same folder shows again with its own root" "$(line 3)" "turn: running for 1 min"

section "two repos"
mkrepo; A=$R; SA=$SD
mkrepo; B=$R; SB=$SD
rs_write "$SA" turn_start "$(ago 50)" "$A"; rs_write "$SA" last_request "alpha request" "$A"
rs_write "$SB" turn_start "$(ago 50)" "$B"; rs_write "$SB" last_request "beta request" "$B"
run "$A"
has "repo A shows its own request" "$(line 3)" "alpha request"
hasnt "repo A does not show the request of B" "$OUT" "beta request"
run "$B"
has "repo B shows its own request" "$(line 3)" "beta request"
hasnt "repo B does not show the request of A" "$OUT" "alpha request"

section "jobs line"
mkrepo
state turn_start "$(ago 100)"
state turn_end "$(ago 10)"
printf 'bash: dev server\nagent: review token=%s\n' "$tok" > "$SD/jobs"
run "$R"
has "the jobs line" "$(line 4)" "jobs at last stop: bash: dev server; agent: review token=***"
hasnt "a token in a job is masked" "$OUT" "$tok"
: > "$SD/jobs"
run "$R"
eq "an empty jobs file gives no jobs line" "$(lines)" 3
rm -f "$SD/jobs"
run "$R"
eq "no jobs file gives no jobs line" "$(lines)" 3
n8=$(rep 'job-line-padding ' 12)
printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n' "$n8" b c d e f g > "$SD/jobs"
run "$R"
eq "many jobs still print one line" "$(lines)" 4

# ---------- no secret in the output of a full run ----------
section "end to end with the hook"
mkrepo
mkdir -p "$R/.real"
printf '{"hook_event_name":"UserPromptSubmit","cwd":"%s","prompt":"deploy with %s and password=hunter22"}' "$R" "$tok" | "$SH" "$ROOT/hooks/claude/real-turn-log.sh"
printf '{"hook_event_name":"Stop","cwd":"%s","stop_hook_active":false,"last_assistant_message":"done.\\nSTATE: done"}' "$R" | "$SH" "$ROOT/hooks/claude/real-turn-log.sh"
run "$R"
eq "the log of the hook and the status agree" "$(line 3 | sed 's/ [0-9]* s ago/ N s ago/')" 'turn: done N s ago - "deploy with ghp_*** and password=***"'
hasnt "no token in the status output" "$OUT" "$tok"
hasnt "no password in the status output" "$OUT" "hunter22"
all=$(cat "$SD"/* 2>/dev/null)
hasnt "no token in a state file" "$all" "$tok"

section "a /real-status turn keeps the record of the last real turn"
mkrepo
hook() { printf '%s' "$1" | "$SH" "$ROOT/hooks/claude/real-turn-log.sh"; }
upj() { printf '{"hook_event_name":"UserPromptSubmit","cwd":"%s","prompt":"%s"}' "$R" "$1"; }
stj() { printf '{"hook_event_name":"Stop","cwd":"%s","stop_hook_active":false,"last_assistant_message":"%s"}' "$R" "$1"; }
hook "$(upj 'fix the login bug')"
hook "$(stj 'Work finished.\nSTATE: done - x')"
rs_write "$SD" turn_start "$(ago 700)" "$R"; rs_write "$SD" turn_end "$(ago 600)" "$R"
run "$R"
eq "10 minutes after the turn" "$(line 3)" 'turn: done - x 10 min ago - "fix the login bug"'
hook "$(upj '/real-status')"
run "$R"
eq "inside /real-status the turn line still shows the last real turn" "$(line 3)" 'turn: done - x 10 min ago - "fix the login bug"'
hasnt "inside /real-status the turn is not running" "$OUT" "running"
hook "$(stj 'Status shown.')"
run "$R"
eq "after the Stop of the status turn the record is the same" "$(line 3)" 'turn: done - x 10 min ago - "fix the login bug"'
hook "$(stj 'The suite passed.\nSTATE: done - e2e suite green')"
run "$R"
eq "a turn with no prompt after /real-status updates the record" "$(line 3 | sed 's/ [0-9]* s ago/ N s ago/')" 'turn: done - e2e suite green N s ago - "fix the login bug"'

echo
printf 'passed: %d, failed: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
