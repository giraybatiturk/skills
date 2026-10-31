#!/bin/sh
# Test the approvals hook and scripts/real-approvals.sh in temporary folders. POSIX sh.
# The script uses a temporary HOME, temporary XDG folders and an empty git config. It never touches ~/.claude, ~/.codex or ~/.config.
# Passes: with jq and without jq, each with the default awk and with original-awk or nawk (a PATH shim), then one pass with bash.
# A pass prints SKIP when a tool is missing. It removes only the temporary folder that it made. Usage: sh scripts/test-real-approvals.sh
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
HOOK=$ROOT/hooks/claude/real-approvals-hook.sh
CLI=$ROOT/scripts/real-approvals.sh
EXAMPLE=$ROOT/hooks/examples/approvals.example.yml

TMP=$(mktemp -d "${TMPDIR:-/tmp}/real-approvals-test.XXXXXX") || exit 1
TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
trap 'exit 1' INT TERM

export HOME=$TMP/user XDG_CONFIG_HOME=$TMP/user/.config XDG_STATE_HOME=$TMP/user/.local/state TMPDIR=$TMP/tmp
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
for v in $(env | sed -n 's/^\(REAL_[A-Za-z_]*\)=.*/\1/p'); do unset "$v"; done
mkdir -p "$HOME" "$TMPDIR" "$TMP/shim" "$TMP/empty"
UT=$XDG_CONFIG_HOME/real/approvals.yml
GD=$XDG_STATE_HOME/real/approvals
R=$TMP/repo
git init -q "$R"
PATH0=$PATH

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL: [%s] %s\n' "$LABEL" "$1"; [ -n "${2:-}" ] && printf '      %s\n' "$2"; return 0; }
section() { printf '== [%s] %s\n' "$LABEL" "$1"; }
skip() { printf 'SKIP: %s\n' "$1"; }
eq() { if [ "$2" = "$3" ]; then ok; else bad "$1" "expected '$3', got '$2'"; fi; }
has() { case $2 in *"$3"*) ok ;; *) bad "$1" "missing text: $3 | in: $2" ;; esac; }
hasnt() { case $2 in *"$3"*) bad "$1" "unexpected text: $3" ;; *) ok ;; esac; }
rx() { if printf '%s\n' "$2" | grep -Eq "$3"; then ok; else bad "$1" "no match for $3 in: $2"; fi; }
lines() { printf '%s\n' "$1" | wc -l | tr -d ' '; }

# ---------- helpers ----------
js() { printf '%s' "$1" | awk 'BEGIN{ORS=""} {gsub(/\\/,"\\\\");gsub(/"/,"\\\"");gsub(/\t/,"\\t"); if(NR>1)printf "\\n"; printf "%s",$0}'; }
jb() { printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","cwd":"%s","tool_input":{"command":"%s"}}' "$R" "$(js "$1")"; }
jt() { printf '{"hook_event_name":"PreToolUse","tool_name":"%s","cwd":"%s","tool_input":{%s}}' "$1" "$R" "${2:-}"; }
jf() { jt "$1" "\"$2\":\"$(js "$3")\""; } # jf TOOL KEY VALUE

# Run the hook. Sets RC, OUT and ERR. Extra arguments are VAR=value pairs for the hook.
hook() { # hook JSON [VAR=value ...]
  hj=$1; shift
  RC=0
  OUT=$(printf '%s' "$hj" | env PATH="$PPATH" ${NOJQ:+REAL_NO_JQ=1} "$@" "$SHBIN" "$HOOK" 2>"$TMP/err") || RC=$?
  ERR=$(cat "$TMP/err")
}
# Run the CLI in the folder $CWDX. Sets RC, OUT and ERR.
cli() { # cli ARGS... (VAR=value pairs go in CLIENV)
  RC=0
  OUT=$(cd "$CWDX" && env PATH="$PPATH" $CLIENV "$SHBIN" "$CLI" "$@" 2>"$TMP/err" </dev/null) || RC=$?
  ERR=$(cat "$TMP/err")
}
CWDX=$R
CLIENV=

expect_ask() { # NAME ID
  if [ "$RC" -ne 0 ]; then bad "$1" "expected exit 0, got $RC. err=$ERR"; return; fi
  case $OUT in *'"permissionDecision":"ask"'*"\"permissionDecisionReason\":\"$2: "*) ok ;; *) bad "$1" "expected an ask with id $2. out=$OUT err=$ERR" ;; esac
}
expect_deny() { # NAME ID
  if [ "$RC" -ne 2 ]; then bad "$1" "expected exit 2, got $RC. out=$OUT err=$ERR"; return; fi
  case $ERR in "real: $2: "*) ok ;; *) bad "$1" "expected a deny with id $2. err=$ERR" ;; esac
}
expect_none() { if [ "$RC" -eq 0 ] && [ -z "$OUT" ]; then ok; else bad "$1" "expected no output. rc=$RC out=$OUT err=$ERR"; fi; }
valid_json() { # NAME TEXT
  if command -v python3 >/dev/null 2>&1; then
    if printf '%s' "$2" | python3 -c 'import json,sys; json.loads(sys.stdin.read())' 2>/dev/null; then ok; else bad "$1" "invalid JSON: $2"; fi
  fi
}

# One command against the table in $TB: WANT is deny, ask or none.
cmd_is() { # WANT COMMAND
  hook "$(jb "$2")" REAL_APPROVALS="$TB"
  case $1 in
    deny) expect_deny "command $1: $2" merge ;;
    ask) expect_ask "command $1: $2" "$3" ;;
    none) expect_none "command none: $2" ;;
  esac
}

# ---------- fixtures ----------
cat > "$TMP/t1.yml" <<'EOF'
# main fixture
- id: tracker-write
  tool: mcp__tracker__*create*|mcp__tracker__*update*
  mode: ask
  why: Show the text first.
- id: tracker-delete
  tool: mcp__tracker__*delete*
  mode: deny
  why: Not reversible.
- id: tracker-read
  tool: mcp__tracker__get_*|mcp__tracker__list_*
  mode: auto
  why: Reads are free.
- id: query-q
  tool: mcp__q__ge?_item
  mode: ask
  why: A question mark is one character.
- id: merge
  command: gh pr merge|glab mr merge
  mode: deny
  why: Only the owner merges.
- id: deploy
  command: vercel --prod|wrangler deploy
  mode: ask
  why: Deploy only when the owner says so.
- id: kube
  command: ?ubectl delete *
  mode: ask
  why: A delete in the cluster asks.
- id: squash
  command: gh pr *squash*
  mode: ask
  why: Squash asks.
- id: build
  command: make|npm run build
  mode: auto
  why: Builds are free.
EOF
TB=$TMP/t1.yml

cat > "$TMP/other.yml" <<'EOF'
- id: other-rule
  tool: mcp__other__zap
  mode: ask
  why: Only an unrelated rule.
EOF

# Valid fixture for the grant tests
cat > "$TMP/g.yml" <<'EOF'
- id: gask
  tool: mcp__g__*create*
  mode: ask
  why: Ask first.
- id: gdeny
  tool: mcp__g__*delete*
  mode: deny
  why: Never.
- id: gauto
  tool: mcp__g__get_x
  mode: auto
  why: Free.
EOF

mkgrant() { # mkgrant ID CONTENT
  mkdir -p "$GD" && chmod 700 "$GD"
  printf '%s' "$2" > "$GD/$1"
}
future() { echo $(( $(date +%s) + ${1:-600} )); }

# Terminal for the grant command: util-linux and BSD script differ.
TERM_MODE=
if command -v script >/dev/null 2>&1; then
  o=$(script -qec 'test -t 0 && echo istty' /dev/null </dev/null 2>/dev/null | tr -d '\r')
  case $o in *istty*) TERM_MODE=linux ;; esac
  if [ -z "$TERM_MODE" ]; then
    o=$(script -q /dev/null sh -c 'test -t 0 && echo istty' </dev/null 2>/dev/null | tr -d '\r')
    case $o in *istty*) TERM_MODE=bsd ;; esac
  fi
fi
term() { # term CMDSTRING: runs the command with a terminal on stdin. Sets RC and OUT.
  RC=0
  case $TERM_MODE in
    linux) env PATH="$PPATH" script -qec "$1" /dev/null </dev/null >"$TMP/term.out" 2>&1 || RC=$? ;;
    bsd) env PATH="$PPATH" script -q /dev/null sh -c "$1" </dev/null >"$TMP/term.out" 2>&1 || RC=$? ;;
  esac
  # macOS script echoes the EOF of the closed stdin as "^D" and two backspaces before the output.
  OUT=$(tr -d '\r' < "$TMP/term.out" | sed "s/^^D$(printf '\b\b')//")
}

# ---------- static ----------
LABEL=static
section "static checks"
for f in "$HOOK" "$CLI" "$ROOT/hooks/claude/real-approvals-lib.sh" "$0"; do
  if sh -n "$f" 2>/dev/null; then ok; else bad "syntax: $f"; fi
  if [ -x "$f" ] || [ "$f" = "$0" ]; then ok; else bad "not executable: $f"; fi
done
grep -q real-hooks-managed "$HOOK" && grep -q real-hooks-managed "$ROOT/hooks/claude/real-approvals-lib.sh" && ok || bad "marker line missing"
if command -v python3 >/dev/null 2>&1; then
  python3 -c 'import json,sys; [json.load(open(f)) for f in sys.argv[1:]]' "$ROOT/hooks/claude/settings.example.json" "$ROOT/hooks/codex/hooks.example.json" 2>/dev/null && ok || bad "settings JSON is invalid"
fi
has "claude settings use the hook with matcher *" "$(tr -d '\n' < "$ROOT/hooks/claude/settings.example.json" | tr -s ' ')" '"matcher": "*", "hooks": [ { "type": "command", "command": "/ABSOLUTE/PATH/TO/skills/hooks/claude/real-approvals-hook.sh"'
has "codex settings run the hook with REAL_ASK_MODE=deny" "$(tr -d '\n' < "$ROOT/hooks/codex/hooks.example.json" | tr -s ' ')" '"matcher": "*", "hooks": [ { "type": "command", "command": "REAL_ASK_MODE=deny /ABSOLUTE/PATH/TO/skills/hooks/claude/real-approvals-hook.sh"'

# ---------- the cases ----------
all_cases() {
  # reset the state of this pass
  rm -rf "$HOME" "$R/.real" "$TMP/pwn"
  mkdir -p "$HOME"
  unset REAL_APPROVALS REAL_ASK_MODE 2>/dev/null || true

  # ===== 1. tool-name match =====
  section "1. tool-name match"
  hook "$(jt mcp__tracker__create_task)" REAL_APPROVALS="$TB"
  expect_ask "ask rule gives an ask JSON" tracker-write
  has "ask reason holds ID: WHY" "$OUT" '"permissionDecisionReason":"tracker-write: Show the text first."'
  hasnt "ask output has no allow" "$OUT" '"allow"'
  valid_json "ask output is valid JSON" "$OUT"
  hook "$(jt mcp__tracker__delete_task)" REAL_APPROVALS="$TB"
  expect_deny "deny rule gives exit 2" tracker-delete
  has "deny stderr holds ID: WHY" "$ERR" "real: tracker-delete: Not reversible."
  hook "$(jt mcp__tracker__get_task)" REAL_APPROVALS="$TB"
  expect_none "auto rule gives no output"
  hook "$(jt mcp__q__get_item)" REAL_APPROVALS="$TB"
  expect_ask "a question mark matches one character" query-q
  hook "$(jt mcp__q__gt_item)" REAL_APPROVALS="$TB"
  expect_none "a question mark does not match no character"
  hook "$(jt MCP__tracker__create_task)" REAL_APPROVALS="$TB"
  expect_none "the match is case sensitive"
  hook "$(jt Read)" REAL_APPROVALS="$TB"
  expect_none "a tool without a rule gives no output"

  # ===== 2. command match =====
  section "2. command match"
  for c in 'gh pr merge 5' 'gh pr merge' 'cd x && GH_TOKEN=1 /usr/bin/GH pr merge 5' 'sudo gh pr merge' "bash -c 'gh pr merge 1'" 'eval "gh pr merge"' \
           'echo $(gh pr merge 2)' 'g\h pr merge' 'xargs -n1 gh pr merge' 'echo "$(gh pr merge 2)"' 'echo `gh pr merge 3`' 'bash -lc "gh pr merge 1"' \
           "sh -c \"bash -c 'gh pr merge 1'\"" '(gh pr merge 1)' 'true || gh pr merge 1' 'gh pr merge 1 &' '\gh pr merge 1' "'gh' pr merge" '"gh" "pr" "merge"' \
           'glab mr merge 3' 'ls 2>&1 | gh pr merge 9' 'if true; then gh pr merge 1; fi' 'nohup gh pr merge 1 >/dev/null 2>&1' 'echo a
gh pr merge 1' 'env FOO=1 gh pr merge' 'gh pr merge 5 --squash' "\$'gh' pr merge 5" '$"gh" pr merge 5'; do
    cmd_is deny "$c"
  done
  for c in "git commit -m 'gh pr merge'" 'echo "gh pr merge"' 'gh pr --repo x merge' 'gh pr view 1' 'gh pr merged' 'ghx pr merge' 'echo gh pr' 'gh pr' \
           'make' 'git status' 'echo hi && ls' 'echo gh-pr-merge' 'git commit -m "fix: gh pr merge"' "echo 'a; gh pr merge'"; do
    cmd_is none "$c"
  done
  cmd_is ask 'vercel --prod' deploy
  cmd_is ask 'cd app && vercel --prod --yes' deploy
  cmd_is ask 'npx wrangler deploy' deploy
  cmd_is ask 'kubectl delete pod x' kube
  cmd_is ask '/usr/local/bin/Kubectl delete ns y' kube
  cmd_is none 'kubectl get pods'
  cmd_is ask 'gh pr --squash 5' squash
  hook "$(jt Bash '"command":""')" REAL_APPROVALS="$TB"
  expect_none "an empty command gives no output"
  hook "$(jt apply_patch "\"command\":\"gh pr merge 1\"")" REAL_APPROVALS="$TB"
  expect_none "a command rule is for the Bash tool only"
  # regex characters in a command pattern are literal
  printf -- '- id: lit\n  command: gh.pr+merge\n  mode: deny\n  why: Literal.\n' > "$TMP/lit.yml"
  hook "$(jb 'gh.pr+merge 1')" REAL_APPROVALS="$TMP/lit.yml"; expect_deny "a dot and a plus in a pattern are literal" lit
  hook "$(jb 'ghXprrmerge 1')" REAL_APPROVALS="$TMP/lit.yml"; expect_none "a dot and a plus in a pattern are not a regex"

  # ===== 3. precedence =====
  section "3. precedence"
  cat > "$TMP/p1.yml" <<'EOF'
- id: p-ask
  tool: mcp__p__*
  mode: ask
  why: Ask.
- id: p-deny
  tool: mcp__p__*x
  mode: deny
  why: Deny.
- id: p-auto
  tool: mcp__p__*y
  mode: auto
  why: Auto.
- id: p-ask2
  tool: mcp__p__*y
  mode: ask
  why: Second ask.
- id: p-ask3
  tool: mcp__p__*z
  mode: ask
  why: First tie.
- id: p-ask4
  tool: mcp__p__*z
  mode: ask
  why: Second tie.
- id: c-deny
  command: gh pr merge
  mode: deny
  why: Deny merge.
- id: c-ask
  command: vercel --prod
  mode: ask
  why: Ask deploy.
EOF
  hook "$(jt mcp__p__x)" REAL_APPROVALS="$TMP/p1.yml"; expect_deny "ask then deny: deny wins" p-deny
  hook "$(jt mcp__p__y)" REAL_APPROVALS="$TMP/p1.yml"; expect_ask "auto and ask: ask wins" p-ask
  hook "$(jt mcp__p__z)" REAL_APPROVALS="$TMP/p1.yml"; expect_ask "a tie keeps the first rule" p-ask
  hook "$(jb 'vercel --prod; gh pr merge 1')" REAL_APPROVALS="$TMP/p1.yml"; expect_deny "two segments, ask then deny: deny wins" c-deny
  hook "$(jb 'gh pr merge 1; vercel --prod')" REAL_APPROVALS="$TMP/p1.yml"; expect_deny "two segments, deny then ask: deny wins" c-deny
  printf -- '- id: e-deny\n  tool: mcp__e__*\n  mode: deny\n  why: D.\n- id: e-ask\n  tool: mcp__e__create\n  mode: ask\n  why: A.\n' > "$TMP/p2.yml"
  hook "$(jt mcp__e__create)" REAL_APPROVALS="$TMP/p2.yml"; expect_deny "deny first, ask second: deny wins" e-deny
  printf -- '- id: t-ask\n  tool: mcp__t__*\n  mode: ask\n  why: A.\n- id: t-auto\n  tool: mcp__t__get\n  mode: auto\n  why: B.\n' > "$TMP/p3.yml"
  hook "$(jt mcp__t__get)" REAL_APPROVALS="$TMP/p3.yml"; expect_ask "ask first, auto second: ask wins" t-ask

  # ===== 4. missing table =====
  section "4. missing table"
  hook "$(jt mcp__tracker__create_task)"; expect_none "no table: an MCP write tool gives no output"
  hook "$(jb 'gh pr merge 1')"; expect_none "no table: Bash gives no output"
  hook "$(jb 'cat ~/.config/real/approvals.yml')"; expect_none "no table: the guard does not run"
  hook "$(jf Write file_path ".real/approvals.yml")"; expect_none "no table: a write to the table path is not blocked"
  hook "$(jt mcp__tracker__create_task)" REAL_APPROVALS=; expect_none "an empty REAL_APPROVALS is not set"
  hook "$(jt mcp__tracker__create_task)" REAL_APPROVALS="$TMP/nope.yml"
  expect_ask "REAL_APPROVALS to a missing file: broken-table" broken-table
  has "missing file: the message" "$OUT" "REAL_APPROVALS points to a missing file"
  printf '' | env PATH="$PPATH" "$SHBIN" "$HOOK" >/dev/null 2>&1; eq "empty input: exit 0" "$?" 0
  hook 'not json at all' REAL_APPROVALS="$TB"; expect_none "invalid input gives no output"

  # ===== 5. broken table =====
  section "5. broken table"
  mkbroken() { printf '%s\n' "$2" > "$TMP/$1.yml"; }
  chk_broken() { # NAME LINE FRAGMENT
    CLIENV="REAL_APPROVALS=$TMP/$1.yml"; cli check
    eq "broken $1: check exits 1" "$RC" 1
    has "broken $1: PATH:LINE: message" "$OUT" "$TMP/$1.yml:$2: $3"
  }
  mkbroken b1 '- id: a
  tool: mcp__a__b
  mode: ask'
  chk_broken b1 1 "missing why"
  mkbroken b2 '- id: a
  tool: mcp__a__b
  mode: maybe
  why: x'
  chk_broken b2 3 "bad mode"
  mkbroken b3 '- id: Bad_Id
  tool: mcp__a__b
  mode: ask
  why: x'
  chk_broken b3 1 "bad id"
  mkbroken b4 '- id: a
  tool: mcp__a__b
  mode: ask
  why: x
- id: a
  tool: mcp__a__c
  mode: ask
  why: y'
  chk_broken b4 5 "duplicate id a"
  mkbroken b5 '- id: none
  tool: mcp__a__b
  mode: ask
  why: x'
  chk_broken b5 1 "reserved id none"
  mkbroken b6 '- id: a
  tool: mcp__a__b
  mode: ask
  colour: red
  why: x'
  chk_broken b6 4 "unknown key colour"
  mkbroken b7 '- id: a
  tool: mcp__a__b
  mode: ask
  why: x
  mode: deny'
  chk_broken b7 5 "duplicate key mode"
  mkbroken b8 '- id: a
  tool: mcp__a__b
  command: gh pr merge
  mode: ask
  why: x'
  chk_broken b8 2 "both tool and command"
  mkbroken b9 '- id: a
  mode: ask
  why: x'
  chk_broken b9 1 "no tool and no command"
  printf -- '- id: a\n  tool: mcp__a__b\n\tmode: ask\n  why: x\n' > "$TMP/b10.yml"
  chk_broken b10 3 "tab in the indentation"
  mkbroken b11 'this is not yaml'
  chk_broken b11 1 "line is not a comment, a rule start or a key"
  mkbroken b12 '- id: a
  tool: mcp__a__(x)
  mode: ask
  why: x'
  chk_broken b12 2 "bad tool alternative"
  alts=a1; i=2; while [ $i -le 21 ]; do alts="$alts|a$i"; i=$((i + 1)); done
  mkbroken b13 "- id: a
  tool: $alts
  mode: ask
  why: x"
  chk_broken b13 2 "too many alternatives"
  long=$(awk 'BEGIN { for (i = 0; i < 501; i++) printf "x" }')
  mkbroken b14 "- id: a
  tool: mcp__a__b
  mode: ask
  why: $long"
  chk_broken b14 4 "value over 500 characters"
  mkbroken b15 '- id: a
  tool: a||b
  mode: ask
  why: x'
  chk_broken b15 2 "empty alternative"
  mkbroken b16 '  id: x'
  chk_broken b16 1 "key outside a rule"
  mkbroken b17 '- id: a
  command: ""
  mode: ask
  why: x'
  chk_broken b17 2 "empty command value"
  mkbroken b18 '- id: a
  tool: mcp__a__b
  mode: ask
  why:'
  chk_broken b18 4 "missing why (the value is empty)"
  # the hook on a broken table
  hook "$(jt mcp__x__create_y)" REAL_APPROVALS="$TMP/b2.yml"
  expect_ask "broken table: an MCP write tool asks with broken-table" broken-table
  has "broken table: the reason names the file and the line" "$OUT" "The approvals table $TMP/b2.yml has an error: line 3: bad mode"
  has "broken table: the ask has a systemMessage" "$OUT" '"systemMessage":"real: the approvals table'
  valid_json "broken table: the ask JSON is valid" "$OUT"
  hook "$(jt Read)" REAL_APPROVALS="$TMP/b2.yml"
  eq "broken table: a Read tool gets only a systemMessage (exit)" "$RC" 0
  case $OUT in '{"systemMessage":"real: the approvals table '*'}') ok ;; *) bad "broken table: a Read tool gets only a systemMessage" "$OUT" ;; esac
  valid_json "broken table: the message JSON is valid" "$OUT"
  hook "$(jt mcp__x__get_y)" REAL_APPROVALS="$TMP/b2.yml"
  case $OUT in '{"systemMessage":'*) ok ;; *) bad "broken table: an MCP read tool gets only a systemMessage" "$OUT" ;; esac
  hook "$(jb 'ls')" REAL_APPROVALS="$TMP/b2.yml"
  case $OUT in '{"systemMessage":'*) ok ;; *) bad "broken table: Bash gets only a systemMessage" "$OUT" ;; esac
  # a valid user table plus a broken repo table
  mkdir -p "$XDG_CONFIG_HOME/real" "$R/.real"
  printf -- '- id: u-deny\n  tool: mcp__x__delete_y\n  mode: deny\n  why: User deny.\n- id: u-auto\n  tool: mcp__x__create_y\n  mode: auto\n  why: User auto.\n' > "$UT"
  cp "$TMP/b2.yml" "$R/.real/approvals.yml"
  hook "$(jt mcp__x__delete_y)"
  expect_deny "valid user table, broken repo table: the user deny rule still denies" u-deny
  has "valid user table, broken repo table: the deny names the broken file" "$ERR" "has an error"
  hook "$(jt mcp__x__create_y)"
  expect_ask "a broken file wins over an auto rule of a valid file" broken-table
  rm -rf "$R/.real" "$XDG_CONFIG_HOME/real"
  # an awk that cannot run the programs gives a visible message, not a silent pass
  mkdir -p "$TMP/badawk"
  printf '#!/bin/sh\ncase "$*" in *"function glob"*|*"function doline"*) exit 2 ;; esac\nexec %s "$@"\n' "$(command -v awk)" > "$TMP/badawk/awk"; chmod +x "$TMP/badawk/awk"
  RC=0; OUT=$(printf '%s' "$(jt mcp__tracker__delete_task)" | env PATH="$TMP/badawk:$PPATH" ${NOJQ:+REAL_NO_JQ=1} REAL_APPROVALS="$TB" "$SHBIN" "$HOOK" 2>/dev/null) || RC=$?
  eq "an awk that fails: exit 0" "$RC" 0
  has "an awk that fails: a visible message" "$OUT" '"systemMessage":"real: the approvals engine gave no result'
  # an awk that fails only for the matcher: an MCP tool and Bash ask (Codex: deny), a read tool gets a warning
  printf '#!/bin/sh\ncase "$*" in *"function consider"*) exit 2 ;; esac\nexec %s "$@"\n' "$(PATH=$PPATH; command -v awk)" > "$TMP/badawk/awk"; chmod +x "$TMP/badawk/awk"
  sv=$PPATH; PPATH=$TMP/badawk:$sv
  hook "$(jt mcp__mail__send_mail)" REAL_APPROVALS="$TB"
  expect_ask "a failed matcher: an MCP tool asks" broken-table
  has "a failed matcher: the reason" "$OUT" "The approvals engine gave no result. Check that awk works."
  valid_json "a failed matcher: the ask JSON is valid" "$OUT"
  hook "$(jb 'gh pr merge 1')" REAL_APPROVALS="$TB"
  expect_ask "a failed matcher: Bash asks" broken-table
  hook "$(jt mcp__mail__send_mail)" REAL_APPROVALS="$TB" REAL_ASK_MODE=deny
  expect_deny "a failed matcher, Codex mode: an MCP tool is denied" broken-table
  has "a failed matcher, Codex mode: the hint" "$ERR" "Fix the table: real-approvals.sh check"
  hook "$(jt Read)" REAL_APPROVALS="$TB"
  case $OUT in '{"systemMessage":"real: the approvals engine gave no result'*'}') ok ;; *) bad "a failed matcher: a Read tool gets only a systemMessage" "rc=$RC out=$OUT" ;; esac
  PPATH=$sv

  # ===== 6. union =====
  section "6. union"
  mkdir -p "$XDG_CONFIG_HOME/real" "$R/.real"
  printf -- '- id: u-deny\n  tool: mcp__u__delete*\n  mode: deny\n  why: User deny.\n' > "$UT"
  printf -- '- id: r-auto\n  tool: mcp__u__delete*\n  mode: auto\n  why: Repo auto.\n- id: r-ask\n  tool: mcp__u__create*\n  mode: ask\n  why: Repo ask.\n' > "$R/.real/approvals.yml"
  hook "$(jt mcp__u__delete_x)"; expect_deny "a repo table cannot remove a user deny rule" u-deny
  hook "$(jt mcp__u__create_x)"; expect_ask "a repo-only rule applies too" r-ask
  hook "$(jt mcp__u__delete_x)" REAL_APPROVALS="$TMP/other.yml"; expect_ask "REAL_APPROVALS replaces both tables (only the default applies)" default-write
  CLIENV=; cli check
  has "check lists the repo table" "$OUT" "$R/.real/approvals.yml: ok (2 rules)"
  has "check lists the user table" "$OUT" "$UT: ok (1 rules)"
  has "check warns about the conflict" "$OUT" "conflict: r-auto (auto) and u-deny (deny) both match 'mcp__u__delete*'. The stricter mode wins: deny."
  eq "check exits 0 with a conflict" "$RC" 0
  rm -f "$R/.real/approvals.yml"; ln -s "$UT" "$R/.real/approvals.yml"
  CLIENV=; cli check
  eq "the same file is read once" "$(printf '%s\n' "$OUT" | grep -c ': ok (')" 1
  rm -rf "$R/.real" "$XDG_CONFIG_HOME/real"
  # a dangling link is a broken table, not a missing one
  mkdir -p "$XDG_CONFIG_HOME/real"; ln -s "$TMP/gone.yml" "$UT"
  hook "$(jt mcp__u__create_x)"; expect_ask "a dangling table link is broken" broken-table
  rm -rf "$XDG_CONFIG_HOME/real"
  CLIENV=; cwdsave=$CWDX; CWDX=$TMP/empty; cli check
  has "no table: check says so" "$OUT" "no approvals table found. Looked at: "
  eq "no table: check exits 0" "$RC" 0
  CWDX=$cwdsave

  # ===== 7. grants =====
  section "7. grants"
  G=$TMP/g.yml
  mkgrant gask "expires=$(future)
"
  hook "$(jt mcp__g__create_x)" REAL_APPROVALS="$G"; expect_none "a valid grant lets an ask rule pass"
  mkgrant gask "expires=$(( $(date +%s) - 5 ))
"
  hook "$(jt mcp__g__create_x)" REAL_APPROVALS="$G"; expect_ask "an expired grant asks again" gask
  for m in 'nonsense' 'expires=abc' "expires=$(future)
second line
" 'expires=' "expires=0$(future)" "  expires=$(future)" ''; do
    mkgrant gask "$m"
    hook "$(jt mcp__g__create_x)" REAL_APPROVALS="$G"; expect_ask "a malformed grant is ignored" gask
  done
  rm -f "$GD/gask"; printf 'expires=%s\n' "$(future)" > "$TMP/real-grant"; ln -s "$TMP/real-grant" "$GD/gask"
  hook "$(jt mcp__g__create_x)" REAL_APPROVALS="$G"; expect_ask "a grant that is a link is ignored" gask
  rm -f "$GD/gask"
  mkgrant gdeny "expires=$(future)
"
  hook "$(jt mcp__g__delete_x)" REAL_APPROVALS="$G"; expect_deny "a deny rule with a grant file still denies" gdeny
  rm -f "$GD/gdeny"
  hook "$(jt mcp__g__publish_x)" REAL_APPROVALS="$G"; expect_ask "an unlisted write tool asks" default-write
  mkgrant default-write "expires=$(future)
"
  hook "$(jt mcp__g__publish_x)" REAL_APPROVALS="$G"; expect_none "a default-write grant lets the unlisted tool pass"
  rm -f "$GD/default-write"
  mkgrant broken-table "expires=$(future)
"
  hook "$(jt mcp__g__create_x)" REAL_APPROVALS="$TMP/b2.yml"; expect_ask "a grant never lifts broken-table" broken-table
  rm -f "$GD/broken-table"
  mkgrant gask "expires=$(future 120)
"
  mkgrant old "expires=1
"
  CLIENV="REAL_APPROVALS=$G"; cli check
  rx "check lists a valid grant" "$OUT" '^grant gask: [12] min left$'
  has "check lists an expired grant" "$OUT" "grant old: expired"
  rm -f "$GD/gask" "$GD/old"
  # the grant command
  CLIENV="REAL_APPROVALS=$G"
  RC=0; OUT=$(cd "$R" && env PATH="$PPATH" REAL_APPROVALS="$G" "$SHBIN" "$CLI" grant gask </dev/null 2>"$TMP/err") || RC=$?; ERR=$(cat "$TMP/err")
  eq "grant without a terminal: exit 1" "$RC" 1
  has "grant without a terminal: the message" "$ERR" "grant needs a terminal"
  [ -e "$GD/gask" ] && bad "grant without a terminal wrote a file" || ok
  if [ -n "$TERM_MODE" ]; then
    term "cd $R && REAL_APPROVALS=$G $SHBIN $CLI grant gask --minutes 10"
    eq "grant with a terminal: exit 0" "$RC" 0
    eq "grant with a terminal: the message" "$OUT" "granted gask for 10 minutes"
    case $(ls -ld "$GD") in drwx------*) ok ;; *) bad "the grants folder is not mode 700" ;; esac
    case $(ls -l "$GD/gask") in -rw-------*) ok ;; *) bad "the grant file is not mode 600" "$(ls -l "$GD/gask")" ;; esac
    rx "the grant file holds expires=EPOCH" "$(cat "$GD/gask")" '^expires=[0-9]{10}$'
    hook "$(jt mcp__g__create_x)" REAL_APPROVALS="$G"; expect_none "a granted rule passes"
    CLIENV="REAL_APPROVALS=$G"; cli explain mcp__g__create_x
    eq "explain shows the grant" "$OUT" "auto gask: Ask first. (granted, 10 min left)"
    term "cd $R && REAL_APPROVALS=$G $SHBIN $CLI grant gdeny"
    eq "grant of a deny rule: exit 1" "$RC" 1
    has "grant of a deny rule: the message" "$OUT" "a deny rule cannot be granted"
    term "cd $R && REAL_APPROVALS=$G $SHBIN $CLI grant gauto"
    eq "grant of an auto rule: exit 1" "$RC" 1
    has "grant of an auto rule: the message" "$OUT" "the rule is auto, there is nothing to grant"
    term "cd $R && REAL_APPROVALS=$G $SHBIN $CLI grant nothing"
    eq "grant of an unknown id: exit 1" "$RC" 1
    term "cd $R && REAL_APPROVALS=$G $SHBIN $CLI grant default-write --minutes 1"
    eq "grant of default-write: exit 0" "$RC" 0
    hook "$(jt mcp__g__publish_x)" REAL_APPROVALS="$G"; expect_none "a default-write grant by the command works"
    term "cd $R && REAL_APPROVALS=$G $SHBIN $CLI grant gask --minutes 0"
    eq "grant with 0 minutes: exit 2" "$RC" 2
    term "cd $R && REAL_APPROVALS=$G $SHBIN $CLI grant gask --minutes 1441"
    eq "grant with 1441 minutes: exit 2" "$RC" 2
    term "cd $R && REAL_APPROVALS=$G $SHBIN $CLI grant gask --minutes abc"
    eq "grant with a bad number: exit 2" "$RC" 2
    term "cd $R && REAL_APPROVALS=$TMP/b2.yml $SHBIN $CLI grant gask"
    eq "grant with a broken table: exit 1" "$RC" 1
    term "cd $R && REAL_APPROVALS=$G $SHBIN $CLI grant ../x"
    eq "grant of a path-like id: exit 1" "$RC" 1
  else
    skip "grant with a terminal: neither util-linux nor BSD script gives a terminal"
  fi
  CLIENV="REAL_APPROVALS=$G"; cli revoke gask
  eq "revoke: exit 0" "$RC" 0
  case $OUT in "revoked gask"|"no grant for gask") ok ;; *) bad "revoke: output" "$OUT" ;; esac
  [ -e "$GD/gask" ] && bad "revoke left the file" || ok
  cli revoke gask; eq "revoke again: no grant" "$OUT" "no grant for gask"
  cli revoke ../x; eq "revoke of ../x is refused" "$RC" 1
  cli revoke 'a/b'; eq "revoke of a/b is refused" "$RC" 1
  cli revoke; eq "revoke without an id: exit 2" "$RC" 2
  mkgrant keep "expires=$(future)
"
  cli revoke keep; eq "revoke removes its file" "$([ -e "$GD/keep" ] && echo yes || echo no)" no
  rm -rf "$HOME/.local"

  # ===== 8. agent writes are denied =====
  section "8. agent writes to the table and the grants"
  mkdir -p "$XDG_CONFIG_HOME/real" "$R/.real"
  cp "$TB" "$UT"; cp "$TB" "$R/.real/approvals.yml"
  for t in "Write:file_path:$R/.real/approvals.yml" "Edit:file_path:.real/approvals.yml" "Write:file_path:$UT" "MultiEdit:file_path:$XDG_CONFIG_HOME/real/approvals.yml" \
           "Write:file_path:$GD/gask" "NotebookEdit:notebook_path:$R/.real/approvals.yml" "mcp__fs__write_file:path:$UT" "Edit:file_path:$R/.real//./approvals.yml" \
           "Write:file_path:$R/.REAL/Approvals.yml"; do
    k=${t#*:}; k=${k%%:*}; name=${t%%:*}; val=${t#*:*:}
    hook "$(jf "$name" "$k" "$val")"
    if [ "$RC" -eq 2 ]; then ok; else bad "$name $k=$val is not denied" "rc=$RC out=$OUT"; fi
    has "$name guard message" "$ERR" "for the user only"
  done
  for c in 'cat > ~/.config/real/approvals.yml' 'echo x > .real//approvals.yml' 'rm -rf $HOME/.local/state/real/approvals' 'sh scripts/real-approvals.sh grant x' \
           'real-approvals.sh grant x --minutes 5' '"/p/real-approvals.sh" grant x' 'REAL-APPROVALS.SH GRANT x' 'sed -i s/ask/auto/ .real/approvals.yml' 'cat .real/./approvals.yml' \
           "*** Update File: .real/approvals.yml" 'cp x ~/.config/real/approvals.yml' 'real-approvals grant x'; do
    hook "$(jb "$c")"
    if [ "$RC" -eq 2 ]; then ok; else bad "Bash is not denied: $c" "rc=$RC out=$OUT"; fi
  done
  hook "$(jt apply_patch "\"command\":\"*** Update File: .real/approvals.yml\"")"
  eq "apply_patch text with the path is denied" "$RC" 2
  hook "$(jf Read file_path "$R/.real/approvals.yml")"; expect_none "Read of the table is allowed"
  hook "$(jf Grep path "$R/.real/approvals.yml")"; expect_none "Grep of the table is allowed"
  hook "$(jf Glob path "$R/.real")"; expect_none "Glob of the folder is allowed"
  for c in 'sh scripts/real-approvals.sh revoke x' 'sh scripts/real-approvals.sh explain foo' 'sh scripts/real-approvals.sh check' 'real-approvals.sh export-omp' 'ls' \
           'sh scripts/real-approvals.sh explain grant'; do
    hook "$(jb "$c")"; expect_none "Bash allowed: $c"
  done
  # REAL_APPROVALS names a table outside the usual folders
  hook "$(jb "cat $TB")" REAL_APPROVALS="$TB"; eq "Bash text with the REAL_APPROVALS path is denied" "$RC" 2
  hook "$(jf Write file_path "$TB")" REAL_APPROVALS="$TB"; eq "Write to the REAL_APPROVALS path is denied" "$RC" 2
  hook "$(jf Write file_path "$TB.new")" REAL_APPROVALS="$TB"; expect_none "Write to another path is allowed"
  # quotes and backslashes do not hide the table path or the grant command
  for c in "echo > ~/.config/real/'approvals.yml'" 'cat ~/.config/real/"approvals".yml' "script -qec \"sh scripts/real-approvals.sh 'grant' merge\" /dev/null" \
           "sh scripts/real-approvals.sh gr''ant x" 'sh scripts/real-approvals.sh \grant x' 'sh scripts/real-approvals.sh "gr"ant x' "sh scripts/real-approvals.sh \$'grant' x" \
           'cat .real/"/"approvals.yml' 'sh scripts/real-approvals.sh \
grant x' 'echo x > ~/.config/real/\
approvals.yml'; do
    hook "$(jb "$c")"
    if [ "$RC" -eq 2 ]; then ok; else bad "Bash with quotes is not denied: $c" "rc=$RC out=$OUT"; fi
  done
  for c in 'sh scripts/real-approvals.sh explain x' 'sh scripts/real-approvals.sh revoke x' "sh scripts/real-approvals.sh 'explain' x" 'sh scripts/real-approvals.sh "revoke" x'; do
    hook "$(jb "$c")"; expect_none "Bash allowed: $c"
  done
  # the user table is a link to a file in another folder
  DT=$TMP/dot/real.local/approvals.yml
  mkdir -p "$TMP/dot/real.local" "$XDG_CONFIG_HOME/real/x"
  cp "$TB" "$DT"; rm -f "$UT"; ln -s "$DT" "$UT"; ln -s "$UT" "$TMP/dot/hop"
  hook "$(jf Edit file_path "$DT")"; eq "Edit of the target of a table link is denied" "$RC" 2; has "the guard message" "$ERR" "for the user only"
  hook "$(jf Write file_path "$TMP/dot/hop")"; eq "Write to a link of a link to the table is denied" "$RC" 2
  hook "$(jf Write file_path "$XDG_CONFIG_HOME/real/x/../approvals.yml")"; eq "Write to a path with .. is denied" "$RC" 2
  hook "$(jf Write file_path "$TMP/dot/real.local/../real.local/approvals.yml")"; eq "Write to the target with .. is denied" "$RC" 2
  hook "$(jb "sed -i s/deny/auto/ $DT")"; eq "Bash on the target of a table link is denied" "$RC" 2
  hook "$(jb "cd $TMP/dot && sed -i s/deny/auto/ real.local/approvals.yml")"; eq "Bash with the last two parts of the target is denied" "$RC" 2
  hook "$(jf Read file_path "$DT")"; expect_none "Read of the target of a table link is allowed"
  hook "$(jf Write file_path "$TMP/dot/real.local/other.yml")"; expect_none "Write to another file in that folder is allowed"
  # a link that points to the table of REAL_APPROVALS, and a loop of links
  ln -s "$TB" "$TMP/lnk.yml"
  hook "$(jf Write file_path "$TB")" REAL_APPROVALS="$TMP/lnk.yml"; eq "Write to the target of the REAL_APPROVALS link is denied" "$RC" 2
  ln -s "$TMP/loopb" "$TMP/loopa"; ln -s "$TMP/loopa" "$TMP/loopb"
  hook "$(jf Write file_path "$TMP/loopa")"; expect_none "a loop of links ends and is allowed"
  rm -rf "$TMP/dot" "$TMP/lnk.yml" "$TMP/loopa" "$TMP/loopb"
  rm -rf "$XDG_CONFIG_HOME/real" "$R/.real"

  # ===== 9. explain =====
  section "9. explain"
  CLIENV="REAL_APPROVALS=$TB"
  cli explain mcp__tracker__create_task; eq "explain a tool: ask" "$OUT" "ask tracker-write: Show the text first."
  eq "explain a tool: exit 0" "$RC" 0
  cli explain mcp__tracker__delete_task; eq "explain a tool: deny" "$OUT" "deny tracker-delete: Not reversible."
  cli explain mcp__tracker__get_task; eq "explain a tool: auto" "$OUT" "auto tracker-read: Reads are free."
  cli explain gh pr merge 5; eq "explain a command (words)" "$OUT" "deny merge: Only the owner merges."
  cli explain 'cd x && gh pr merge 5'; eq "explain a command (one argument)" "$OUT" "deny merge: Only the owner merges."
  cli explain make; eq "explain a command of one word" "$OUT" "auto build: Builds are free."
  cli explain Read; eq "explain: no match for a tool" "$OUT" "auto none: No rule matches."
  cli explain echo hello; eq "explain: no match for a command" "$OUT" "auto none: No rule matches."
  cli explain mcp__other__create_thing
  eq "explain: default-write" "$OUT" "ask default-write: The tool name has the write verb create and no rule in the approvals table."
  eq "explain prints one line" "$(lines "$OUT")" 1
  CWDX=$TMP/empty; CLIENV=; cli explain mcp__x__create_y; eq "explain: no table" "$OUT" "auto none: No approvals table found."
  CWDX=$R
  mkgrant tracker-write "expires=$(future)
"
  CLIENV="REAL_APPROVALS=$TB"; cli explain mcp__tracker__create_task
  eq "explain: granted" "$OUT" "auto tracker-write: Show the text first. (granted, 10 min left)"
  rm -rf "$HOME/.local"
  cli explain; eq "explain without an argument: exit 2" "$RC" 2
  cli; eq "no command: exit 2" "$RC" 2
  cli nonsense; eq "unknown command: exit 2" "$RC" 2
  cli --help; eq "--help: exit 0" "$RC" 0
  has "--help: usage" "$OUT" "real-approvals.sh check"

  # ===== 10. export-omp =====
  section "10. export-omp"
  cat > "$TMP/x.yml" <<'EOF'
- id: ex-ask
  tool: mcp__tracker__create_task
  mode: ask
  why: Ask.
- id: ex-deny
  tool: mcp__tracker__delete_task|mcp__tracker__create_task
  mode: deny
  why: Deny.
- id: ex-glob
  tool: mcp__tracker__*update*
  mode: ask
  why: Glob.
- id: ex-auto
  tool: mcp__tracker__get_task
  mode: auto
  why: Auto.
- id: ex-cmd
  command: gh pr merge
  mode: deny
  why: Command.
- id: ex-builtin
  tool: Write|mcp__a__b_c
  mode: ask
  why: Built-in.
- id: ex-repeat
  tool: mcp__srv__srv_x
  mode: ask
  why: Repeat.
EOF
  printf 'mcp__tracker__update_task\nmcp__tracker__get_task\nmcp__tracker__create_comment\nbad name!\nmcp__tracker__list_tasks\nmcp__shop__send_invoice\n' > "$TMP/names.txt"
  before=$(find "$HOME" "$R" -print | sort; git -C "$ROOT" status --short)
  CLIENV="REAL_APPROVALS=$TMP/x.yml"; cli export-omp
  eq "export: exit 0" "$RC" 0
  eq "export: the header" "$(printf '%s\n' "$OUT" | sed -n 1p)" "# omp tools.approval block from the approvals table. Merge it into the omp config by hand. This command writes no file."
  eq "export: tools key" "$(printf '%s\n' "$OUT" | sed -n 2p)" "tools:"
  eq "export: approval key" "$(printf '%s\n' "$OUT" | sed -n 3p)" "  approval:"
  has "export: a deny rule wins for a name that two rules give" "$OUT" "    mcp__tracker_create_task: deny # ex-deny"
  has "export: a delete name" "$OUT" "    mcp__tracker_delete_task: deny # ex-deny"
  has "export: a repeated server prefix is stripped" "$OUT" "    mcp__srv_x: prompt # ex-repeat"
  has "export: the mcp name of a mixed rule" "$OUT" "    mcp__a_b_c: prompt # ex-builtin"
  has "export: a glob without --tools is a comment" "$OUT" "# ex-glob: mcp__tracker__*update* needs exact tool names. Run export-omp --tools FILE."
  has "export: a command rule is a comment" "$OUT" "# ex-cmd: runs through the hook with REAL_ASK_MODE=deny"
  has "export: a built-in tool is a comment" "$OUT" "# ex-builtin: built-in tool names differ in omp. Set it by hand."
  hasnt "export: an auto rule is not printed" "$OUT" "get_task"
  eq "export: no duplicate key" "$(printf '%s\n' "$OUT" | grep -E '^    mcp__' | sed 's/:.*//' | sort | uniq -d | wc -l | tr -d ' ')" 0
  eq "export: names are sorted" "$(printf '%s\n' "$OUT" | grep -E '^    mcp__' | sed 's/:.*//')" "$(printf '%s\n' "$OUT" | grep -E '^    mcp__' | sed 's/:.*//' | LC_ALL=C sort)"
  cli export-omp --tools "$TMP/names.txt"
  eq "export --tools: exit 0" "$RC" 0
  has "export --tools: a glob matches the listed name" "$OUT" "    mcp__tracker_update_task: prompt # ex-glob"
  has "export --tools: default-write for a listed write name" "$OUT" "    mcp__tracker_create_comment: prompt # default-write"
  has "export --tools: default-write for another server" "$OUT" "    mcp__shop_send_invoice: prompt # default-write"
  hasnt "export --tools: a read name is not printed" "$OUT" "list_tasks"
  hasnt "export --tools: a bad name is skipped" "$OUT" "bad name"
  hasnt "export --tools: the glob comment is gone" "$OUT" "needs exact tool names"
  CLIENV="REAL_APPROVALS=$TMP/x.yml"
  RC=0; OUT=$(cd "$R" && printf 'mcp__tracker__update_task\n' | env PATH="$PPATH" REAL_APPROVALS="$TMP/x.yml" "$SHBIN" "$CLI" export-omp --tools - 2>/dev/null) || RC=$?
  has "export --tools - reads stdin (pipe)" "$OUT" "mcp__tracker_update_task: prompt # ex-glob"
  after=$(find "$HOME" "$R" -print | sort; git -C "$ROOT" status --short)
  eq "export writes no file" "$after" "$before"
  CLIENV="REAL_APPROVALS=$TMP/b2.yml"; cli export-omp
  eq "export of a broken table: exit 1" "$RC" 1
  eq "export of a broken table: no stdout" "$OUT" ""
  CLIENV="REAL_APPROVALS=$TMP/b2.yml"; RC=0; ERR=$(cd "$R" && env PATH="$PPATH" REAL_APPROVALS="$TMP/b2.yml" "$SHBIN" "$CLI" export-omp 2>&1 >/dev/null </dev/null) || RC=$?
  has "export of a broken table: errors on stderr" "$ERR" "$TMP/b2.yml:3: bad mode"
  printf -- '- id: only-auto\n  tool: mcp__a__b\n  mode: auto\n  why: x\n' > "$TMP/xa.yml"
  CLIENV="REAL_APPROVALS=$TMP/xa.yml"; cli export-omp
  has "export with no entry: an empty map" "$OUT" "  approval: {}"
  CLIENV="REAL_APPROVALS=$TMP/x.yml"; cli export-omp --tools "$TMP/names.txt"
  eq "export: every line is a comment, a key or a name line" "$(printf '%s\n' "$OUT" | grep -Evc '^(#.*|tools:|  approval:|    mcp__[A-Za-z0-9_.:-]+: (prompt|deny) # [a-z0-9-]+)$')" 0
  cli export-omp
  eq "export without --tools: every line is a comment, a key or a name line" "$(printf '%s\n' "$OUT" | grep -Evc '^(#.*|tools:|  approval:|    mcp__[A-Za-z0-9_.:-]+: (prompt|deny) # [a-z0-9-]+)$')" 0
  if python3 -c 'import yaml' 2>/dev/null; then
    CLIENV="REAL_APPROVALS=$TMP/x.yml"; cli export-omp --tools "$TMP/names.txt"
    printf '%s\n' "$OUT" | python3 -c 'import sys,yaml; d=yaml.safe_load(sys.stdin); assert isinstance(d["tools"]["approval"], dict)' 2>/dev/null && ok || bad "export is not valid YAML"
  else
    skip "export YAML parse: python3 has no yaml module"
  fi

  # ===== 11. secret masking =====
  section "11. secret masking"
  ghp="ghp_$(printf '%036d' 0 | tr 0 a)"; aws="AKIA$(printf '%016d' 0 | tr 0 A)"
  sk="sk-$(printf '%030d' 0 | tr 0 b)"; xox="xoxb-$(printf '%012d' 0 | tr 0 1)"; gl="glpat-$(printf '%024d' 0 | tr 0 c)"
  jwt="eyJ$(printf '%012d' 0 | tr 0 a).eyJ$(printf '%012d' 0 | tr 0 b).$(printf '%012d' 0 | tr 0 c)"
  pk="-----BEGIN RSA PRIVATE"' KEY-----'
  cat > "$TMP/m.yml" <<EOF
- id: m-ask
  tool: mcp__m__ask
  mode: ask
  why: A $ghp and $aws and password=hunter2xyz end
- id: m-deny
  tool: mcp__m__deny
  mode: deny
  why: B $sk $xox $gl $jwt token=abcdef $pk body
- id: m-pw
  tool: mcp__m__pw
  mode: ask
  why: C API_KEY=zzz123 apikey=yyy456 secret=xxx789
EOF
  hook "$(jt mcp__m__ask)" REAL_APPROVALS="$TMP/m.yml"
  has "mask: the ask JSON has [masked]" "$OUT" "[masked]"
  for s in "$ghp" "$aws" hunter2xyz; do hasnt "mask: the ask JSON hides $s" "$OUT" "$s"; done
  has "mask: the text around stays" "$OUT" "A [masked] and [masked] and password=[masked] end"
  hook "$(jt mcp__m__deny)" REAL_APPROVALS="$TMP/m.yml"
  has "mask: the deny stderr has [masked]" "$ERR" "[masked]"
  for s in "$sk" "$xox" "$gl" "$jwt" abcdef BEGIN; do hasnt "mask: the deny stderr hides $s" "$ERR" "$s"; done
  hook "$(jt mcp__m__pw)" REAL_APPROVALS="$TMP/m.yml"
  for s in zzz123 yyy456 xxx789; do hasnt "mask: the value $s is hidden" "$OUT" "$s"; done
  CLIENV="REAL_APPROVALS=$TMP/m.yml"; cli explain mcp__m__ask
  has "mask: explain has [masked]" "$OUT" "[masked]"
  hasnt "mask: explain hides the token" "$OUT" "$ghp"
  hasnt "mask: explain hides the password" "$OUT" "hunter2xyz"
  cli check
  hasnt "mask: check hides the token" "$OUT" "$ghp"
  # a token in the path of a broken table
  tpath="$TMP/$ghp.yml"; printf 'junk\n' > "$tpath"
  hook "$(jt mcp__x__create_y)" REAL_APPROVALS="$tpath"
  has "mask: a token in a path is masked" "$OUT" "[masked]"
  hasnt "mask: a token in a path is not printed" "$OUT" "$ghp"
  rm -f "$tpath"
  # the text is cut to 300 characters
  l300=$(awk 'BEGIN { for (i = 0; i < 400; i++) printf "w" }')
  printf -- '- id: long\n  tool: mcp__l__x\n  mode: deny\n  why: %s\n' "$l300" > "$TMP/long.yml"
  hook "$(jt mcp__l__x)" REAL_APPROVALS="$TMP/long.yml"
  has "a long reason is cut with ..." "$ERR" "www..."
  hasnt "a long reason is cut to 300 characters" "$ERR" "$(awk 'BEGIN { for (i = 0; i < 301; i++) printf "w" }')"

  # ===== 12. Codex mode =====
  section "12. Codex mode"
  hook "$(jt mcp__tracker__create_task)" REAL_APPROVALS="$TB" REAL_ASK_MODE=deny
  expect_deny "Codex: an ask becomes exit 2" tracker-write
  has "Codex: the grant hint" "$ERR" "This client cannot ask. The user can allow the rule for a time with: real-approvals.sh grant tracker-write --minutes 10"
  hook "$(jt mcp__tracker__delete_task)" REAL_APPROVALS="$TB" REAL_ASK_MODE=deny
  expect_deny "Codex: a deny stays a deny" tracker-delete
  hasnt "Codex: a deny has no grant hint" "$ERR" "grant"
  hook "$(jt mcp__zzz__create_x)" REAL_APPROVALS="$TB" REAL_ASK_MODE=deny
  expect_deny "Codex: default-write is a deny" default-write
  has "Codex: the default-write hint" "$ERR" "real-approvals.sh grant default-write --minutes 10"
  hook "$(jt mcp__x__create_y)" REAL_APPROVALS="$TMP/b2.yml" REAL_ASK_MODE=deny
  expect_deny "Codex: broken-table is a deny" broken-table
  has "Codex: the broken-table hint" "$ERR" "Fix the table: real-approvals.sh check"
  hook "$(jt mcp__tracker__get_task)" REAL_APPROVALS="$TB" REAL_ASK_MODE=deny
  expect_none "Codex: an auto rule gives no output"
  hook "$(jb 'vercel --prod')" REAL_APPROVALS="$TB" REAL_ASK_MODE=deny
  expect_deny "Codex: a command ask is a deny" deploy

  # ===== 13. default for an unlisted write tool =====
  section "13. unlisted write tools"
  O=$TMP/other.yml
  for n in mcp__x__create_item mcp__x__update_item mcp__x__delete_item mcp__x__send_mail mcp__x__post_message mcp__x__publish_page mcp__x__move_task mcp__x__merge_pr \
           mcp__x__remove_item mcp__x__add_label mcp__x__set_status mcp__x__edit_doc mcp__x__write_note mcp__x__comment_task mcp__x__submit_form mcp__x__share_file \
           mcp__x__upload_file mcp__x__archive_item mcp__x__deploy_app mcp__gh__createIssue mcp__x__postMessage mcp__x__create mcp__x_create_item mcp__tracker_create_task; do
    hook "$(jt "$n")" REAL_APPROVALS="$O"; expect_ask "unlisted write tool asks: $n" default-write
  done
  hook "$(jt mcp__gh__createIssue)" REAL_APPROVALS="$O"
  has "default-write names the verb" "$OUT" "The tool name has the write verb create and no rule in the approvals table."
  for n in mcp__x__list_items mcp__x__get_settings mcp__mem0__search_memories mcp__x__list_posts mcp__x__getUpdatedItems mcp__x__GetSettings mcp__x__read_file mcp__x__fetch; do
    hook "$(jt "$n")" REAL_APPROVALS="$O"; expect_none "unlisted read tool gives no output: $n"
  done
  for n in Write Edit MultiEdit WebFetch Task NotebookEdit; do
    hook "$(jt "$n")" REAL_APPROVALS="$O"; expect_none "a non-MCP tool with a verb gets no default ask: $n"
  done
  hook "$(jt mcp_x__create_item)" REAL_APPROVALS="$O"; expect_none "a name that starts with mcp_ is not an MCP tool"
  hook "$(jt mcp__other__zap)" REAL_APPROVALS="$O"; expect_ask "a listed tool uses its rule, not default-write" other-rule
  printf -- '- id: auto-create\n  tool: mcp__x__create_item\n  mode: auto\n  why: Free.\n' > "$TMP/ac.yml"
  hook "$(jt mcp__x__create_item)" REAL_APPROVALS="$TMP/ac.yml"; expect_none "an auto rule turns the default ask off for that tool"

  # ===== 14. hostile tables =====
  section "14. hostile tables"
  awk 'BEGIN { for (i = 0; i < 4000; i++) print "# padding padding padding padding padding padding" }' > "$TMP/h1.yml"
  CLIENV="REAL_APPROVALS=$TMP/h1.yml"; cli check
  eq "a 200 KB file is broken: exit 1" "$RC" 1
  has "a 200 KB file: the size message" "$OUT" "the table is larger than 131072 bytes"
  hook "$(jt mcp__x__create_y)" REAL_APPROVALS="$TMP/h1.yml"; expect_ask "a 200 KB file: the hook asks with broken-table" broken-table
  for cb in '\000' '\001' '\010' '\033' '\177' '\037'; do
    printf -- "- id: a\n  tool: mcp__a__b\n  mode: ask\n  why: x${cb}y\n" > "$TMP/h2.yml"
    CLIENV="REAL_APPROVALS=$TMP/h2.yml"; cli check
    eq "a control byte $cb is broken: exit 1" "$RC" 1
    has "a control byte $cb: the message" "$OUT" "the table holds a control byte"
  done
  printf -- '- id: a\n  tool: mcp__a__b\n  mode: ask\n  why: x\ty\n' > "$TMP/h3.yml"
  CLIENV="REAL_APPROVALS=$TMP/h3.yml"; cli check; eq "a tab inside a value is allowed" "$RC" 0
  printf -- '- id: a\r\n  tool: mcp__a__b\r\n  mode: ask\r\n  why: x\r\n' > "$TMP/h4.yml"
  hook "$(jt mcp__a__b)" REAL_APPROVALS="$TMP/h4.yml"; expect_ask "CRLF line ends are accepted" a
  has "CRLF: no CR in the reason" "$OUT" '"permissionDecisionReason":"a: x"'
  printf '\357\273\277- id: a\n  tool: mcp__a__b\n  mode: ask\n  why: x\n' > "$TMP/h5.yml"
  hook "$(jt mcp__a__b)" REAL_APPROVALS="$TMP/h5.yml"; expect_ask "a UTF-8 BOM on line 1 is accepted" a
  printf -- '- id: a\n  tool: "mcp__a__b"\n  mode: ask\n  why: '"'"'quoted text'"'"'\n' > "$TMP/h6.yml"
  hook "$(jt mcp__a__b)" REAL_APPROVALS="$TMP/h6.yml"; expect_ask "one pair of quotes is removed" a
  has "quotes removed from the value" "$OUT" '"permissionDecisionReason":"a: quoted text"'
  printf -- '- id: a\n  tool: mcp__a__b\n  mode: ask\n  why: Caf\303\251 \305\237 \304\261\n' > "$TMP/h7.yml"
  hook "$(jt mcp__a__b)" REAL_APPROVALS="$TMP/h7.yml"
  has "UTF-8 text in a value is kept" "$OUT" 'Caf'"$(printf '\303\251')"' '"$(printf '\305\237')"' '"$(printf '\304\261')"
  valid_json "UTF-8 reason is valid JSON" "$OUT"
  awk 'BEGIN { for (i = 1; i <= 501; i++) printf "- id: r%d\n  tool: mcp__r__t%d\n  mode: ask\n  why: x\n", i, i }' > "$TMP/h8.yml"
  CLIENV="REAL_APPROVALS=$TMP/h8.yml"; cli check
  eq "501 rules are broken: exit 1" "$RC" 1
  has "501 rules: the message with the line" "$OUT" "$TMP/h8.yml:2001: more than 500 rules"
  awk 'BEGIN { for (i = 1; i <= 500; i++) printf "- id: r%d\n  tool: mcp__r__t%d\n  mode: ask\n  why: x\n", i, i }' > "$TMP/h9.yml"
  CLIENV="REAL_APPROVALS=$TMP/h9.yml"; cli check; eq "500 rules are valid: exit 0" "$RC" 0
  has "500 rules: the count" "$OUT" "ok (500 rules)"
  # a reason with shell and format characters stays inert text
  mkdir -p "$TMP/pwn"
  cat > "$TMP/h10.yml" <<EOF
- id: hostile
  tool: mcp__h__*
  mode: ask
  why: touch $TMP/pwn/PWNED3 %s %d; \$(touch $TMP/pwn/PWNED) \`touch $TMP/pwn/PWNED2\` \\n \\ "dq" 'sq' \\033[31m \\u001b[0m
EOF
  hook "$(jt mcp__h__create_x)" REAL_APPROVALS="$TMP/h10.yml"
  expect_ask "hostile reason: ask" hostile
  valid_json "hostile reason: the JSON is valid" "$OUT"
  has "hostile reason: the text is printed as is" "$OUT" 'touch '"$TMP"'/pwn/PWNED3 %s %d'
  eq "hostile reason: no file is made" "$(ls "$TMP/pwn" | wc -l | tr -d ' ')" 0
  eq "hostile reason: no ESC byte in the output" "$(printf '%s' "$OUT" | LC_ALL=C tr -d '\033' | wc -c | tr -d ' ')" "$(printf '%s' "$OUT" | wc -c | tr -d ' ')"
  sed 's/mode: ask/mode: deny/' "$TMP/h10.yml" > "$TMP/h11.yml"
  hook "$(jt mcp__h__create_x)" REAL_APPROVALS="$TMP/h11.yml"
  expect_deny "hostile reason: deny" hostile
  eq "hostile reason: deny makes no file" "$(ls "$TMP/pwn" | wc -l | tr -d ' ')" 0
  CLIENV="REAL_APPROVALS=$TMP/h10.yml"; cli explain mcp__h__create_x
  has "hostile reason: explain prints it as text" "$OUT" 'touch '"$TMP"'/pwn/PWNED3 %s %d'
  eq "hostile reason: explain makes no file" "$(ls "$TMP/pwn" | wc -l | tr -d ' ')" 0
  printf -- '- id: esc\n  tool: mcp__e__*\n  mode: ask\n  why: before\033[31mafter\n' > "$TMP/h12.yml"
  hook "$(jt mcp__e__create_x)" REAL_APPROVALS="$TMP/h12.yml"
  eq "an ESC byte in the table: no ESC in the output" "$(printf '%s' "$OUT" | LC_ALL=C tr -d '\033' | wc -c | tr -d ' ')" "$(printf '%s' "$OUT" | wc -c | tr -d ' ')"
  # regex characters are not regex
  printf -- '- id: dotstar\n  tool: mcp__a__.*\n  mode: deny\n  why: A dot and a star.\n' > "$TMP/h13.yml"
  hook "$(jt mcp__a__create)" REAL_APPROVALS="$TMP/h13.yml"; expect_ask "mcp__a__.* is a glob, not a regex: no match for create" default-write
  hook "$(jt mcp__a__.x)" REAL_APPROVALS="$TMP/h13.yml"; expect_deny "mcp__a__.* matches a literal dot" dotstar
  for bad in 'mcp__a__(x)' 'mcp__a__[xy]' 'mcp__a__x+' 'mcp__a__x$' '^mcp__a__x' 'mcp__a__{2}' 'mcp__a__x y' 'mcp__a__x\y' 'mcp__a__x/y'; do
    printf -- '- id: rx\n  tool: %s\n  mode: deny\n  why: Bad.\n' "$bad" > "$TMP/h14.yml"
    CLIENV="REAL_APPROVALS=$TMP/h14.yml"; cli check
    eq "a tool alternative with $bad is an error" "$RC" 1
  done
  # a long single line without a newline, and many alternatives
  alts=a1; i=2; while [ $i -le 20 ]; do alts="$alts|mcp__m__a$i"; i=$((i + 1)); done
  printf -- '- id: twenty\n  tool: %s\n  mode: deny\n  why: Twenty.\n' "$alts" > "$TMP/h15.yml"
  CLIENV="REAL_APPROVALS=$TMP/h15.yml"; cli check; eq "20 alternatives are valid" "$RC" 0
  hook "$(jt mcp__m__a20)" REAL_APPROVALS="$TMP/h15.yml"; expect_deny "the 20th alternative matches" twenty

  # ===== 15. performance =====
  section "15. performance"
  awk 'BEGIN {
    for (i = 1; i <= 300; i++) printf "- id: tl%d\n  tool: mcp__srv%d__*create*|mcp__srv%d__get_%d\n  mode: %s\n  why: Tool rule %d.\n", i, i, i, i, (i % 3 == 0 ? "deny" : (i % 3 == 1 ? "ask" : "auto")), i
    for (i = 1; i <= 198; i++) printf "- id: cm%d\n  command: tool%d run|tool%d --flag *x*\n  mode: %s\n  why: Command rule %d.\n", i, i, i, (i % 2 ? "ask" : "auto"), i
    printf "- id: cmerge\n  command: gh pr merge\n  mode: deny\n  why: Merge.\n- id: ckube\n  command: ?ubectl delete *\n  mode: ask\n  why: Kube.\n"
  }' > "$TMP/big.yml"
  CLIENV="REAL_APPROVALS=$TMP/big.yml"; cli check; has "the 500 rule table is valid" "$OUT" "ok (500 rules)"
  for kind in oneword words lines quotes; do
    case $kind in
      oneword) big="echo $(awk 'BEGIN { for (i = 0; i < 200000; i++) printf "A" }'); gh pr merge 1" ;;
      words) big="ls $(awk 'BEGIN { for (i = 0; i < 30000; i++) printf "a%d ", i }') ; gh pr merge 1" ;;
      lines) big=$(awk 'BEGIN { for (i = 0; i < 5000; i++) printf "echo hello world %d; ls -la /tmp/x%d\n", i, i; printf "gh pr merge 1" }') ;;
      quotes) big="echo '$(awk 'BEGIN { for (i = 0; i < 200000; i++) printf "B" }')' \"\$(echo $(awk 'BEGIN { for (i = 0; i < 1000; i++) printf "c " }'))\" && gh pr merge 1" ;;
    esac
    printf '%s' "$(jb "$big")" > "$TMP/bigin.json"
    t0=$(date +%s); RC=0
    OUT=$(env PATH="$PPATH" ${NOJQ:+REAL_NO_JQ=1} REAL_APPROVALS="$TMP/big.yml" "$SHBIN" "$HOOK" < "$TMP/bigin.json" 2>"$TMP/err") || RC=$?
    ERR=$(cat "$TMP/err"); t1=$(date +%s)
    expect_deny "a 200 KB command ($kind) still finds the merge" cmerge
    [ $((t1 - t0)) -le 2 ] && ok || bad "a 200 KB command ($kind) took $((t1 - t0)) s with a 500 rule table"
  done
  t0=$(date +%s)
  hook "$(jb "echo $(awk 'BEGIN { for (i = 0; i < 50000; i++) printf "ab " }') kubectl delete x")" REAL_APPROVALS="$TMP/big.yml"
  t1=$(date +%s)
  expect_ask "a pattern with a glob in the first word finds a late match" ckube
  [ $((t1 - t0)) -le 2 ] && ok || bad "a glob first word took $((t1 - t0)) s"
  # many index hits in one segment: the first word git hits 50000 times, the glob rule must still run in linear time
  printf -- '- id: nforce\n  command: git push *--force*\n  mode: deny\n  why: No force push.\n' > "$TMP/force.yml"
  t0=$(date +%s)
  hook "$(jb "$(awk 'BEGIN { for (i = 0; i < 50000; i++) printf "git " }')push --force")" REAL_APPROVALS="$TMP/force.yml"
  t1=$(date +%s)
  expect_deny "50000 words git then push --force is denied" nforce
  [ $((t1 - t0)) -le 2 ] && ok || bad "50000 words git then push --force took $((t1 - t0)) s"
  # nested -c and eval strings: the rescans must not multiply. The work budget stops them and the command asks.
  nest() { # nest WRAP TAIL WORDS: three levels of WRAP "..." around WORDS times "x y " and TAIL. Sets NQ.
    NQ="$(awk -v n="$3" 'BEGIN { for (i = 0; i < n; i++) printf "x y " }')$2"
    for k in 1 2 3; do NQ="$1 \"$(printf '%s' "$NQ" | sed 's/[\\"$`]/\\&/g')\""; done
  }
  timed() { # timed COMMAND: the hook with the 500 rule table. Sets RC, OUT, ERR and EL (whole seconds).
    printf '%s' "$(jb "$1")" > "$TMP/bigin.json"
    t0=$(date +%s); RC=0
    OUT=$(env PATH="$PPATH" ${NOJQ:+REAL_NO_JQ=1} REAL_APPROVALS="$TMP/big.yml" "$SHBIN" "$HOOK" < "$TMP/bigin.json" 2>"$TMP/err") || RC=$?
    ERR=$(cat "$TMP/err"); EL=$(($(date +%s) - t0))
  }
  nest 'eval sh -c' 'gh pr merge 1' 51200; timed "$NQ"
  expect_ask "3 nested levels of eval sh -c (200 KB): the budget gives an ask" broken-table
  has "3 nested levels of eval sh -c: the reason" "$OUT" "The command is too long or too nested to check."
  [ "$EL" -le 2 ] && ok || bad "3 nested levels of eval sh -c took $EL s"
  nest 'sh -c' 'gh pr merge 1' 51200; timed "$NQ"
  expect_ask "3 nested levels of sh -c (200 KB): the budget gives an ask" broken-table
  [ "$EL" -le 2 ] && ok || bad "3 nested levels of sh -c took $EL s"
  nest 'eval sh -c' 'echo ok' 51200; timed "$NQ"
  expect_ask "3 nested levels without a deny: the budget gives an ask" broken-table
  [ "$EL" -le 2 ] && ok || bad "3 nested levels without a deny took $EL s"
  timed "$(awk 'BEGIN { for (i = 0; i < 40000; i++) printf "eval " }')gh pr merge 1"
  expect_deny "40000 eval words: the deny in the top-level words wins" cmerge
  [ "$EL" -le 2 ] && ok || bad "40000 eval words took $EL s"
  nest 'sh -c' 'gh pr merge 1' 4000; timed "$NQ"
  expect_deny "3 nested levels of 16 KB stay under the budget and find the merge" cmerge

  # ===== 16. spoof =====
  section "16. spoof of the tool name"
  S1=$(printf '{"hook_event_name":"PreToolUse","tool_name":"mcp__tracker__delete_task","cwd":"%s","tool_input":{"tool_name":"Read","file_path":"x"}}' "$R")
  hook "$S1" REAL_APPROVALS="$TB"; expect_deny "an MCP call with tool_name Read in its input is still matched" tracker-delete
  S2=$(printf '{"hook_event_name":"PreToolUse","tool_name":"mcp__tracker__create_task","cwd":"%s","tool_input":{"title":"x","tool_name":"Bash","cwd":"/nowhere","command":"ls"}}' "$R")
  hook "$S2" REAL_APPROVALS="$TB"; expect_ask "tool_name, cwd and command in the input do not change the match" tracker-write
  S3=$(printf '{"hook_event_name":"PreToolUse","tool_name":"mcp__tracker__delete_task","cwd":"%s","tool_input":{"note":"a \\"tool_name\\":\\"Read\\" b"}}' "$R")
  hook "$S3" REAL_APPROVALS="$TB"; expect_deny "a quoted tool_name in a string value does not change the match" tracker-delete
  S4=$(printf '{"tool_name": "mcp__tracker__delete_task" , "cwd" : "%s", "tool_input": {"tool_name" : "Read"}}' "$R")
  hook "$S4" REAL_APPROVALS="$TB"; expect_deny "spaces around the colon" tracker-delete
  S5=$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","cwd":"%s","tool_input":{"command":"gh pr merge 1","tool_name":"Read"}}' "$R")
  hook "$S5" REAL_APPROVALS="$TB"; expect_deny "a Bash call with tool_name Read in its input is still Bash" merge
}

# ---------- the passes ----------
AWKBIN=
for a in original-awk nawk; do command -v "$a" >/dev/null 2>&1 && { AWKBIN=$(command -v "$a"); break; }; done
[ -n "$AWKBIN" ] && ln -s "$AWKBIN" "$TMP/shim/awk"
if [ -n "$AWKBIN" ] && cmp -s "$(command -v awk)" "$AWKBIN"; then
  printf 'NOTE: %s is the same program as awk on this machine. The nawk passes repeat the default awk passes.\n' "$AWKBIN"
fi
HAVEJQ=0; command -v jq >/dev/null 2>&1 && HAVEJQ=1
command -v python3 >/dev/null 2>&1 || skip "JSON validity checks: python3 is missing"
[ -n "$TERM_MODE" ] || skip "the grant command with a terminal: no usable script command"

run_pass() { # run_pass LABEL NOJQ(1 or empty) AWK(default or nawk) SHELL
  LABEL=$1; NOJQ=$2; SHBIN=$4
  PPATH=$PATH0
  [ "$3" = nawk ] && PPATH=$TMP/shim:$PATH0
  all_cases
}
if [ "$HAVEJQ" = 1 ]; then run_pass "jq, default awk" "" default sh; else LABEL=jq; skip "pass with jq: jq is missing"; fi
run_pass "no jq, default awk" 1 default sh
if [ -n "$AWKBIN" ]; then
  if [ "$HAVEJQ" = 1 ]; then run_pass "jq, $(basename "$AWKBIN")" "" nawk sh; else LABEL=jq; skip "pass with jq and $(basename "$AWKBIN"): jq is missing"; fi
  run_pass "no jq, $(basename "$AWKBIN")" 1 nawk sh
else
  LABEL=nawk; skip "passes with nawk: no nawk or original-awk binary"
fi
if command -v bash >/dev/null 2>&1; then
  run_pass "bash, default awk" "$([ "$HAVEJQ" = 1 ] || echo 1)" default bash
else
  LABEL=bash; skip "bash pass: bash is missing"
fi

echo
printf 'passed: %d, failed: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
