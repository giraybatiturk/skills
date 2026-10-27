#!/bin/sh
# real-hooks-managed
# State helpers for the turn log, the Stop banner and scripts/real-status.sh. Source this file. Do not run it.
# It reads no standard input, so a script that already reads its own input can source it.
# State folder: ${XDG_STATE_HOME:-$HOME/.local/state}/real/turn/<key>/ where <key> is "<crc>-<length>" (cksum) of the repo root.
#   root          the absolute repo root (or the working folder outside git). It proves who owns the folder.
#   turn_start    epoch seconds, written at UserPromptSubmit of a real prompt
#   last_request  first 160 characters of the prompt, one line, secrets masked
#   turn_end      epoch seconds, written at Stop
#   state         text after "STATE:" of the last STATE line of the reply. Removed at Stop when the reply has none.
#   jobs          in-flight background tasks at the last Stop, one for each line. Removed at Stop when there are none.
#   status_prompt epoch seconds, written at UserPromptSubmit of a /real-status prompt. A real prompt removes it.
#                 While it is set, a Stop with no STATE line changes no file. The banner counts from the later of turn_start and status_prompt.
# The layout is stable. Later hooks read these files. Every file is one line, except jobs.

rs_root() { # $1 = folder. Prints the git root, or the folder itself outside git.
  git -C "$1" rev-parse --show-toplevel 2>/dev/null || (cd "$1" 2>/dev/null && pwd -P)
}

rs_subagent() { # Succeeds when the hook input is from a subagent: it has agent_id. Needs lib.sh (rh_input, rh_have_jq, rh_field).
  # shortcut: without jq, agent_id is found at any depth, so a background task with an agent_id looks like a subagent. Install jq to fix this.
  if rh_have_jq; then rs_a=$(printf '%s' "$rh_input" | jq -r '.agent_id // empty' 2>/dev/null); else rs_a=$(rh_field agent_id); fi
  [ -n "$rs_a" ]
}

rs_key() { # $1 = root. cksum gives the same value on Linux and macOS.
  printf '%s' "$1" | cksum | awk '{ print $1 "-" $2 }'
}

rs_dir() { # $1 = root. Prints the state folder. Fails when there is no base folder.
  rs_b=${XDG_STATE_HOME:-${HOME:+$HOME/.local/state}}
  [ -n "$rs_b" ] || return 1
  printf '%s/real/turn/%s\n' "$rs_b" "$(rs_key "$1")"
}

rs_owned() { # $1 = state folder, $2 = root. Succeeds when the folder belongs to that root (two roots can share a key).
  [ -n "$1" ] && [ -f "$1/root" ] || return 1
  rs_r=
  { IFS= read -r rs_r; } 2>/dev/null < "$1/root"
  [ "$rs_r" = "$2" ]
}

rs_read() { # $1 = state folder, $2 = file name, $3 = root. Prints the first line. Prints nothing when the file is missing or the folder is not owned.
  rs_owned "$1" "$3" || return 0
  [ -f "$1/$2" ] || return 0
  rs_v=
  { IFS= read -r rs_v; } 2>/dev/null < "$1/$2"
  printf '%s\n' "$rs_v"
}

rs_write() { # $1 = state folder, $2 = file name, $3 = value, $4 = root. Fails, with no output, when it cannot write or the folder is owned by another root.
  (
    umask 077
    mkdir -p "$1" || exit 1
    if [ -e "$1/root" ]; then
      rs_owned "$1" "$4" || exit 1
    else
      printf '%s\n' "$4" > "$1/root" || exit 1
    fi
    t=$1/.tmp.$$
    printf '%s\n' "$3" > "$t" && mv -f "$t" "$1/$2" || { rm -f "$t"; exit 1; }
  ) >/dev/null 2>&1
}

# Mask secrets. Standard input to standard output, one pass for each line.
# Patterns: token prefixes (GitHub, GitLab, Stripe, Slack, AWS, Google, sk-), Bearer and Basic values, key=value pairs,
# JWT strings, user:password in a URL, and the rest of a private key line.
# A case-insensitive match uses bracket classes, because the sed "I" flag is not portable.
rs_mask() {
  sed -E \
    -e 's#(-----BEGIN [A-Z ]*PRIVATE KEY-----).*#\1 ***#' \
    -e 's#://[^/[:space:]@]*:[^/[:space:]@]*@#://***@#g' \
    -e 's#(^|[^A-Za-z0-9])(gh[pousr]_|github_pat_|glpat-|[sr]k_live_|sk_test_|sk-|xox[abprs]-|AKIA|AIza)[A-Za-z0-9_-]{8,}#\1\2***#g' \
    -e 's#eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_.-]*#***#g' \
    -e 's#(^|[^A-Za-z0-9])([Bb][Ee][Aa][Rr][Ee][Rr]|[Bb][Aa][Ss][Ii][Cc])[[:space:]]+[A-Za-z0-9._~+/=-]{8,}#\1\2 ***#g' \
    -e 's#(([Tt][Oo][Kk][Ee][Nn]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]|[Pp][Aa][Ss][Ss][Ww][Dd]|[Aa][Pp][Ii][_-]?[Kk][Ee][Yy]|[Aa][Uu][Tt][Hh][Oo][Rr][Ii][Zz][Aa][Tt][Ii][Oo][Nn])[A-Za-z_]*["'\'']?[[:space:]]*[=:][[:space:]]*)[^[:space:]]+#\1***#g'
}

rs_clean() { # Remove control characters and CR. A tab becomes a space. A newline stays.
  tr '\011' ' ' | tr -d '\000-\010\013-\037\177'
}

# $1 = number of characters. Cuts each line. It counts characters, not bytes: cut -c counts bytes on GNU and characters on macOS.
# A lead byte of UTF-8 starts a character. A continuation byte (0x80 to 0xBF) never does, so a cut never splits a character.
rs_cut() {
  LC_ALL=C awk -v n="$1" '{
    c = 0
    for (i = 1; i <= length($0); i++) {
      b = substr($0, i, 1)
      if (b < "\200" || b >= "\300") if (++c > n) break
    }
    print substr($0, 1, i - 1)
  }'
}

# A reply on standard input. Prints the text after "STATE:" of the LAST line that starts with it.
# Leading spaces and the characters * _ ` > are allowed before the word, and are removed around the text.
rs_state_line() {
  awk '{
    l = $0; sub(/^[[:space:]*_`>]+/, "", l)
    if (match(l, /^STATE[*_`]*:/)) {
      t = substr(l, RLENGTH + 1); sub(/^[[:space:]*_`>]+/, "", t); sub(/[[:space:]*_`>]+$/, "", t)
      last = t; found = 1
    }
  }
  END { if (found) print last }'
}

# A reply on standard input. Prints the first line that has text, with the leading # > * - and spaces removed.
rs_first_line() {
  awk '{ l = $0; sub(/^[[:space:]#>*-]+/, "", l); sub(/[[:space:]]+$/, "", l); if (l != "") { print l; exit } }'
}
