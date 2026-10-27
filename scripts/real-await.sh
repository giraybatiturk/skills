#!/bin/sh
# real-await.sh: wait for a human step (a login, a download, a merge, a code), then exit. No model call.
# Start it as a background command after you ask the user for the step. The end of the job wakes the agent.
#
# Usage:
#   real-await.sh file GLOB [--stable 3]
#   real-await.sh http URL [--status 200] [--contains TEXT]
#   real-await.sh pr NUMBER [--state merged|closed]
#   real-await.sh cmd 'COMMAND'
#   real-await.sh pid PID
#   common: --timeout SECONDS (default 600, 1800 for pr)  --message TEXT  --interval SECONDS (default 5)  --no-notify
#   real-await.sh -h | --help
#
# The probe is the first argument. The first other argument is GLOB, URL, NUMBER, COMMAND or PID. Options use the
# form "--option VALUE" and can come before or after it. Every check is one "try". A try stops after 10 s.
#   file  a file that matches GLOB exists and its size has not changed for --stable seconds. A name that ends in
#         .crdownload .part .partial .download or .tmp does not count. A leading ~/ is your home folder.
#   http  the URL answers with --status (default 200) and, with --contains, the body holds TEXT. No redirect is followed.
#   pr    the pull request is merged. With --state closed it is closed or merged. Uses gh, or glab for a gitlab origin.
#   cmd   "sh -c COMMAND" exits 0. The last 5 lines of its output are printed, masked, before the last line.
#         A background child that COMMAND does not wait for keeps running. Each try starts one more.
#   pid   the process does not exist, or it is a zombie (ended, and its parent did not wait yet).
# One notification comes at the start, from hooks/claude/notify.sh. --no-notify turns it off.
# While it waits, the script writes a wait file in the state folder of the repo for scripts/real-status.sh.
# A new wait first removes the wait files of dead or past waits (a wait that got KILL cannot remove its own).
# Output: the last line is "HUMAN_STEP_DONE after <s>s" (exit 0) or "HUMAN_STEP_TIMEOUT" (exit 3).
# Exit codes: 0 passed, 3 timeout, 2 bad input, 129 HUP, 130 INT, 143 TERM (no HUMAN_STEP line), 1 no temp folder.

set -f
unset CDPATH

usage() { sed -n '2,/^$/p' "$0" | sed -e '$d' -e 's/^# \{0,1\}//'; }
case ${1:-} in
  -h|--help) usage; exit 0 ;;
esac

here=$(dirname "$0")/../hooks/claude
. "$here/lib.sh" < /dev/null # lib.sh reads standard input
. "$here/real-state-lib.sh"

# The reason never shows an option value or the GLOB, URL, NUMBER, COMMAND or PID: they can hold a secret.
# It can show an unknown probe or option name, masked.
die() {
  printf 'real-await: %s\n' "$(printf '%s' "$1" | rs_clean | tr '\n' ' ' | rs_mask | rs_cut 160)" >&2
  exit 2
}
whole() { # $1 = text, $2 = largest value. Succeeds for a whole number from 1 to $2, digits only. Sets n with no leading zeros.
  case $1 in ''|*[!0-9]*) return 1 ;; esac
  n=$1
  while [ "${n#0}" != "$n" ]; do n=${n#0}; done
  [ -n "$n" ] && [ ${#n} -le ${#2} ] && [ "$n" -ge 1 ] && [ "$n" -le "$2" ]
}

# 1. Input
probe=${1:-}
case $probe in
  file|http|pr|cmd|pid) shift ;;
  '') die "no probe (file, http, pr, cmd or pid)" ;;
  *) die "unknown probe: $probe" ;;
esac
timeout= interval=5 stable=3 status=200 contains= state=merged msg= notify=1 pos= has=0
while [ $# -gt 0 ]; do
  case $1 in
    --no-notify) notify=0 ;;
    --timeout|--interval|--message|--stable|--status|--contains|--state)
      opt=$1
      [ $# -ge 2 ] || die "no value for $opt"
      shift
      case $opt in
        --timeout) whole "$1" 86400 || die "bad $opt: use a whole number from 1 to 86400"; timeout=$n ;;
        --interval) whole "$1" 86400 || die "bad $opt: use a whole number from 1 to 86400"; interval=$n ;;
        --message) msg=$1 ;;
        --stable)
          [ "$probe" = file ] || die "$opt is only for file"
          whole "$1" 86400 || die "bad $opt: use a whole number from 1 to 86400"; stable=$n ;;
        --status)
          [ "$probe" = http ] || die "$opt is only for http"
          case $1 in [1-5][0-9][0-9]) status=$1 ;; *) die "bad $opt: use three digits, 100 to 599" ;; esac ;;
        --contains)
          [ "$probe" = http ] || die "$opt is only for http"
          [ -n "$1" ] || die "empty $opt"
          contains=$1 ;;
        --state)
          [ "$probe" = pr ] || die "$opt is only for pr"
          case $1 in merged|closed) state=$1 ;; *) die "bad $opt: use merged or closed" ;; esac ;;
      esac ;;
    -?*) die "unknown option: ${1%%=*}" ;;
    *) [ "$has" = 0 ] || die "more than one argument for $probe"; pos=$1; has=1 ;;
  esac
  shift
done
[ "$has" = 1 ] || die "no argument for $probe"
[ -n "$timeout" ] || { [ "$probe" = pr ] && timeout=1800 || timeout=600; }
root=$(rs_root "$PWD")
[ -n "$root" ] || root=$PWD
case $probe in
  file|cmd) [ -n "$pos" ] || die "empty argument for $probe" ;;
  http)
    case $pos in http://?*|https://?*) ;; *) die "bad URL: it must start with http:// or https://" ;; esac
    case $pos in *[[:space:][:cntrl:]]*) die "bad URL: it has a space or a control character" ;; esac
    command -v curl >/dev/null 2>&1 || die "curl is missing" ;;
  pr|pid)
    [ ${#pos} -le 10 ] && whole "$pos" 9999999999 || die "bad number: use 1 to 10 digits, not 0"
    pos=$n ;;
esac
if [ "$probe" = pid ]; then
  command -v ps >/dev/null 2>&1 || die "ps is missing"
fi
if [ "$probe" = pr ]; then
  cli=gh
  case $(git -C "$root" remote get-url origin 2>/dev/null | tr 'A-Z' 'a-z') in *gitlab*) cli=glab ;; esac
  if [ "$cli" = gh ] && ! command -v gh >/dev/null 2>&1; then cli=glab; fi
  command -v "$cli" >/dev/null 2>&1 || die "the CLI for pr is missing ($cli)"
  export GH_PROMPT_DISABLED=1
fi
if [ -z "$msg" ]; then
  case $probe in
    file) msg="file $pos" ;;
    http) msg="URL $pos" ;;
    pr) msg="PR $pos $state" ;;
    cmd) msg="command $(printf '%s' "$pos" | rs_clean | tr '\n' ' ' | rs_mask | rs_cut 40)" ;;
    pid) msg="process $pos" ;;
  esac
fi
msg=$(printf '%s' "$msg" | rs_clean | tr '\n' ' ' | rs_mask | rs_cut 160)

# 2. Tries. Each try runs in a background subshell and prints to $tmp/out. Exit 0 means the check passed
# (for file: the try ended and printed the signature).
try_file() { # The glob runs with no field splitting. The subshell drops IFS and the glob option after the try.
  case $pos in '~/'*) g=$HOME/${pos#??} ;; *) g=$pos ;; esac
  IFS=
  set +f
  set -- $g
  set -f
  for f; do
    [ -f "$f" ] && [ -r "$f" ] || continue
    case $f in *.crdownload|*.part|*.partial|*.download|*.tmp) continue ;; esac
    printf '%s %s\n' "$(wc -c < "$f" 2>/dev/null | tr -d ' ')" "$f"
  done
}
try_http() {
  rm -f "$tmp/body"
  # -g: no URL globbing, so [1-3] and {a,b} are not expanded into more requests or more hosts.
  c=$(curl -q -s -g -o "$tmp/body" -w '%{http_code}' --max-time "$lim" -- "$pos") && [ "$c" = "$status" ] || return 1
  # shortcut: TEXT with a newline matches when any of its lines matches. Use one line of text.
  [ -z "$contains" ] || LC_ALL=C grep -Fq -e "$contains" "$tmp/body"
}
try_pr() {
  if [ "$cli" = gh ]; then
    s=$(gh pr view "$pos" --json state --jq .state </dev/null 2>/dev/null) || return 1
  else
    j=$(glab mr view "$pos" --output json </dev/null 2>/dev/null) || return 1
    if rh_have_jq; then
      s=$(printf '%s' "$j" | jq -r '.state // empty' 2>/dev/null)
    else # the first merged, closed or opened value: a user object also has a "state" key (active)
      s=$(printf '%s' "$j" | grep -Eo '"state"[[:space:]]*:[[:space:]]*"(merged|closed|opened)"' | head -n 1 | sed 's/.*"\([a-z]*\)"$/\1/')
    fi
  fi
  case $(printf '%s' "$s" | tr 'A-Z' 'a-z') in
    merged) return 0 ;;
    closed) [ "$state" = closed ] ;;
    *) return 1 ;;
  esac
}
try_cmd() { sh -c "$pos" </dev/null; }
# kill -0 would say "exists" for a process of another user (EPERM), so ps decides. A zombie has ended: its parent did not wait yet.
try_pid() { case $(ps -p "$pos" -o stat= 2>/dev/null) in ''|Z*) return 0 ;; esac; return 1; }

# 3. Try runner. No job control (dash has none without a tty), so the tree is found with ps.
tree() { # $1 = pid. Prints the pid and all its descendants.
  ps -A -o pid= -o ppid= 2>/dev/null | awk -v r="$1" '
    { p[NR] = $1; q[NR] = $2 }
    END { s[r] = 1
      do { c = 0; for (i = 1; i <= NR; i++) if (!(p[i] in s) && (q[i] in s)) { s[p[i]] = 1; c = 1 } } while (c)
      for (k in s) print k }'
}
stop() { # $1 = pid. TERM to the pid and its descendants, KILL after 1 s to what is left.
  stl=$(tree "$1")
  kill -TERM $stl 2>/dev/null
  sleep 1
  for stp in $stl; do kill -0 "$stp" 2>/dev/null && kill -KILL "$stp" 2>/dev/null; done
  return 0
}
run_try() { # $1 = limit in seconds, $2... = the try. Sets rc. A try that runs past the limit is stopped (rc is not 0).
  lim=$1; shift
  rm -f "$tmp/fired"
  ( "$@" ) >"$tmp/out" 2>&1 </dev/null &
  tp=$!
  ( sleep "$lim"; : > "$tmp/fired"; stop "$tp" ) &
  wd=$!
  wait "$tp" 2>/dev/null; rc=$?
  if [ -e "$tmp/fired" ]; then # the watchdog sends the KILL after 1 s: let it finish
    wait "$wd" 2>/dev/null
  else
    kill $(tree "$wd") 2>/dev/null
    wait "$wd" 2>/dev/null
  fi
  tp= wd=
}

# 4. Exit: the wait file, the sleep, the try, the watchdog and the temp folder go away. The signals call exit,
# so this runs for them too. A second signal during the cleanup is ignored.
tp= wd= sp= wf=
cleanup() {
  trap '' INT TERM HUP
  [ -n "$wf" ] && rm -f "$wf"
  [ -n "$sp" ] && kill "$sp" 2>/dev/null
  [ -n "$wd" ] && kill $(tree "$wd") 2>/dev/null
  [ -n "$tp" ] && stop "$tp"
  [ -n "${tmp:-}" ] && rm -rf "$tmp"
  return 0
}
tmp=$(mktemp -d "${TMPDIR:-/tmp}/real-await.XXXXXX") || { printf 'real-await: cannot make a temp folder\n' >&2; exit 1; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

# 5. Wait file, then the one notification
start=$(date +%s)
deadline=$((start + timeout))
sd=$(rs_dir "$root") || sd=
# A wait that got KILL leaves its file. Remove the stale ones (past deadline, or a PID that does not run) before our own.
# Only names wait.<1 to 10 digits>. kill -0 is fine here: same user, same state folder. PID 0 would mean our own group.
if [ -n "$sd" ] && rs_owned "$sd" "$root"; then
  for w in $(ls "$sd" 2>/dev/null | grep '^wait\.[0-9]\{1,10\}$'); do
    w_p=${w#wait.}
    w_d=$(rs_read "$sd" "$w" "$root" | awk '{ print $2 }')
    if [ "$w_p" -le 0 ] || ! kill -0 "$w_p" 2>/dev/null; then
      rm -f "$sd/$w"
    else
      case $w_d in ''|*[!0-9]*|?????????????*) ;; *) [ "$w_d" -gt "$start" ] || rm -f "$sd/$w" ;; esac
    fi
  done
fi
if [ -n "$sd" ] && rs_write "$sd" "wait.$$" "$start $deadline $probe $msg" "$root"; then wf=$sd/wait.$$; fi
if [ "$notify" = 1 ]; then
  if [ "$timeout" -ge 60 ]; then lt="$(((timeout + 59) / 60)) min"; else lt="$timeout s"; fi
  # A text that starts with "-" would be read as an option by notify-send.
  jm=$(printf '%s, times out in %s' "$(printf '%s' "$msg" | sed 's/^[[:space:]-]*//')" "$lt" | rh_json_str)
  jc=$(printf '%s' "$root" | rh_json_str)
  printf '{"hook_event_name":"Notification","notification_type":"idle_prompt","title":"Waiting for you","message":%s,"cwd":%s}' "$jm" "$jc" \
    | sh "$here/notify.sh" >/dev/null 2>&1
fi

# 6. Loop. The last try starts at least 1 s before the deadline. The sleep is a background job, so a signal ends it at once.
finish() { # $1 = last line, $2 = exit code
  if [ "$probe" = cmd ]; then
    # C locale: BSD sed stops at a byte that is not valid UTF-8 in the output of a command.
    ( LC_ALL=C; export LC_ALL; tail -n 5 "$tmp/out" 2>/dev/null | rs_clean | rs_mask | rs_cut 160 )
  fi
  printf '%s\n' "$1"
  exit "$2"
}
prev= since=0
while :; do
  now=$(date +%s)
  [ "$now" -lt "$deadline" ] || finish HUMAN_STEP_TIMEOUT 3
  lim=$((deadline - now))
  [ "$lim" -le 10 ] || lim=10
  run_try "$lim" "try_$probe"
  ok=
  if [ "$rc" -eq 0 ]; then
    if [ "$probe" = file ]; then
      sig=$(cat "$tmp/out")
      if [ -z "$sig" ]; then prev=
      elif [ "$sig" != "$prev" ]; then prev=$sig; since=$now
      fi
      [ -z "$sig" ] || [ $(($(date +%s) - since)) -lt "$stable" ] || ok=1
    else
      ok=1
    fi
  fi
  [ -z "$ok" ] || finish "HUMAN_STEP_DONE after $(($(date +%s) - start))s" 0
  nap=$((deadline - $(date +%s)))
  [ "$nap" -le "$interval" ] || nap=$interval
  if [ "$nap" -ge 1 ]; then
    sleep "$nap" &
    sp=$!
    wait "$sp" 2>/dev/null
    sp=
  fi
done
