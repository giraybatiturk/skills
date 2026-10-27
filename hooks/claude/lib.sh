# real-hooks-managed
# Shared helpers for the real agent hooks. Source this file. Do not run it.
# The hooks read one JSON object on stdin. They use jq when it exists.
# Without jq they use sed. Set REAL_NO_JQ=1 to force the sed path.

rh_input=$(cat)

rh_have_jq() { [ -z "${REAL_NO_JQ:-}" ] && command -v jq >/dev/null 2>&1; }

rh_unescape() { # JSON string body on stdin, plain text on stdout
  awk '{ gsub(/\\\\/, "\001"); gsub(/\\"/, "\""); gsub(/\\n/, "\n"); gsub(/\\t/, "\t"); gsub(/\\\//, "/"); gsub(/\001/, "\\"); printf "%s", $0 }'
}

rh_field() { # $1 = key name. Prints the first string value of that key.
  if rh_have_jq; then
    printf '%s' "$rh_input" | jq -r --arg k "$1" '[.. | objects | select(has($k)) | .[$k] | select(type=="string")] | first // empty'
  else
    printf '%s' "$rh_input" | sed -nE "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"(([^\"\\\\]|\\\\.)*)\".*/\1/p" | head -n 1 | rh_unescape
  fi
}

rh_true() { # $1 = key name. Succeeds when the value is true.
  if rh_have_jq; then
    [ "$(printf '%s' "$rh_input" | jq -r --arg k "$1" '[.. | objects | select(has($k)) | .[$k]] | first // false')" = true ]
  else
    printf '%s' "$rh_input" | grep -Eq "\"$1\"[[:space:]]*:[[:space:]]*true"
  fi
}

rh_cwd() {
  d=$(rh_field cwd)
  if [ -n "$d" ] && [ -d "$d" ]; then printf '%s\n' "$d"; else printf '.\n'; fi
}

rh_root() {
  git -C "$(rh_cwd)" rev-parse --show-toplevel 2>/dev/null || rh_cwd
}

rh_cfg() { # $1 = key such as gate.test. Order: env REAL_GATE_TEST, .real-hooks, git config real.hooks.<key>
  envname=REAL_$(printf '%s' "$1" | tr 'a-z.-' 'A-Z__')
  eval "v=\${$envname:-}"
  if [ -n "$v" ]; then printf '%s\n' "$v"; return 0; fi
  root=$(rh_root)
  if [ -f "$root/.real-hooks" ]; then
    v=$(sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$root/.real-hooks" | head -n 1 | sed 's/[[:space:]]*$//')
    if [ -n "$v" ]; then printf '%s\n' "$v"; return 0; fi
  fi
  git -C "$root" config --get "real.hooks.$1" 2>/dev/null || true
}

rh_json_str() { # plain text on stdin, a JSON string (with quotes) on stdout
  tr -d '\000-\010\013\014\016-\037' | awk 'BEGIN { ORS = ""; printf "\"" }
    { gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t"); gsub(/\r/, ""); if (NR > 1) printf "\\n"; printf "%s", $0 }
    END { printf "\"" }'
}

rh_block() { # Exit 2 blocks the action. The text on stderr is the reason.
  printf 'real: %s\n' "$*" >&2
  exit 2
}

# Split a shell command into one segment for each line.
# The quoted text is removed, so "&&" inside a commit message does not split.
rh_segments_noquoted() {
  printf '%s' "$1" | sed -e "s/\"[^\"]*\"//g" -e "s/'[^']*'//g" -e 's/\$(/;/g' | tr ';&|`' '\n\n\n\n'
}

# Same split, but only the quote characters are removed. Targets such as "$HOME" stay visible.
rh_segments_unquoted() {
  printf '%s' "$1" | tr -d "\"'" | sed -e 's/\$(/;/g' | tr ';&|`' '\n\n\n\n'
}

rh_default_branch() {
  git -C "$(rh_cwd)" symbolic-ref --short -q refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||'
}

rh_on_protected_branch() {
  b=$(git -C "$(rh_cwd)" symbolic-ref --short -q HEAD 2>/dev/null || true)
  [ -z "$b" ] && return 1
  case $b in main|master) return 0 ;; esac
  d=$(rh_default_branch)
  [ -n "$d" ] && [ "$b" = "$d" ] && return 0
  return 1
}

# Regex for the start of a git command: env assignments and global options are allowed.
RH_GIT='^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*(command[[:space:]]+)?git([[:space:]]+(-C[[:space:]]+[^[:space:]]+|-c[[:space:]]+[^[:space:]]+|--[a-z-]+(=[^[:space:]]+)?))*[[:space:]]+'
