# real-hooks-managed
# Helpers for the task contract (.real/contract.md). Source this file. Do not run it.
# It reads no standard input, so the hooks and scripts/real-contract.sh can both source it.
# POSIX sh. A path in SCOPE or DO NOT TOUCH is a glob: `*` also matches `/`, so `src/**` and `src/*` match the same files.

rc_dir() { printf '%s/.real\n' "$1"; } # $1 = repo root

rc_file() { printf '%s/.real/contract.md\n' "$1"; }

rc_header() { # $1 = contract file, $2 = key (Task, Status, Owner). Prints the value.
  sed -n "s/^$2:[[:space:]]*//p" "$1" 2>/dev/null | head -n 1 | sed 's/[[:space:]]*$//'
}

rc_status() { # $1 = repo root. Prints draft, active or done in lower case. Prints nothing when there is no contract.
  f=$(rc_file "$1")
  [ -f "$f" ] || return 0
  rc_header "$f" Status | tr 'A-Z' 'a-z'
}

rc_section() { # $1 = contract file, $2 = section name. Prints the bullet lines ("- ", "* ", "1. " or "1) "), one for each line, cleaned.
  awk -v want="$2" '
    /^##[[:space:]]/ { name = $0; sub(/^##[[:space:]]+/, "", name); sub(/[[:space:]]+$/, "", name); insec = (name == want); next }
    insec && /^[[:space:]]*([-*]|[0-9]+[.)])[[:space:]]+/ {
      line = $0
      sub(/^[[:space:]]*([-*]|[0-9]+[.)])[[:space:]]+/, "", line)
      sub(/^\[[ xX~]\][[:space:]]*/, "", line)
      gsub(/`/, "", line)
      sub(/[[:space:]]*<!--.*$/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (line == "" || line ~ /^</) next
      print line
    }' "$1"
}

# ---------- paths ----------

rc_collapse() { # $1 = absolute path. Removes "." and ".." parts and doubled slashes.
  printf '%s\n' "$1" | awk -F/ '{
    n = 0
    for (i = 1; i <= NF; i++) {
      if ($i == "" || $i == ".") continue
      if ($i == "..") { if (n > 0) n--; continue }
      p[++n] = $i
    }
    out = ""
    for (i = 1; i <= n; i++) out = out "/" p[i]
    print (out == "" ? "/" : out)
  }'
}

rc_abs() { # $1 = path, $2 = working folder. Prints an absolute path. Symlinks in the existing part are resolved.
  p=$1
  case $p in /*) ;; *) p=$2/$p ;; esac
  p=$(rc_collapse "$p")
  d=$p
  rest=
  while [ ! -d "$d" ] && [ "$d" != / ]; do
    rest=/$(basename "$d")$rest
    d=$(dirname "$d")
  done
  base=$(cd "$d" 2>/dev/null && pwd -P) || base=$d
  [ "$base" = / ] && base=
  printf '%s%s\n' "$base" "$rest"
}

rc_rel() { # $1 = absolute path, $2 = repo root. Prints the path relative to the root. Fails when the path is outside.
  root=$(cd "$2" 2>/dev/null && pwd -P) || root=$2
  case $1 in
    "$root"/*) printf '%s\n' "${1#"$root"/}" ;;
    *) return 1 ;;
  esac
}

rc_match() { # $1 = relative path, $2 = glob from the contract. Succeeds when the path matches.
  g=$2
  g=${g#./}
  g=${g#/}
  [ -n "$g" ] || return 1
  case $g in */) g="$g*" ;; esac
  case $1 in $g) return 0 ;; esac
  case $g in *'*'*|*'?'*|*'['*) : ;; *) case $1 in "$g"/*) return 0 ;; esac ;; esac
  return 1
}

rc_first_match() { # $1 = relative path, $2 = list of globs (one for each line). Prints the first glob that matches.
  while IFS= read -r g; do
    [ -n "$g" ] || continue
    if rc_match "$1" "$g"; then printf '%s\n' "$g"; return 0; fi
  done <<RC_LIST
$2
RC_LIST
  return 1
}

rc_is_temp() { # $1 = absolute path. Scratch folders are never in the scope of a contract.
  case $1 in
    /tmp/*|/private/tmp/*|/var/tmp/*|/var/folders/*|/private/var/folders/*|/dev/*) return 0 ;;
  esac
  [ -n "${TMPDIR:-}" ] && case $1 in "${TMPDIR%/}"/*) return 0 ;; esac
  return 1
}

# ---------- claims, evidence and the check of DONE WHEN ----------

rc_claims_file() { printf '%s/.real/claims.md\n' "$1"; }
rc_evidence_file() { printf '%s/.real/evidence.jsonl\n' "$1"; }

rc_evidence_exit() { # $1 = repo root, $2 = evidence id. Prints the exit code of that command. Prints nothing when the id is unknown.
  ev=$(rc_evidence_file "$1")
  [ -f "$ev" ] || return 0
  line=$(grep -F "\"id\":\"$2\"" "$ev" | head -n 1)
  [ -n "$line" ] || return 0
  printf '%s' "$line" | sed -nE 's/.*"exit":("?[A-Za-z0-9-]+"?).*/\1/p' | tr -d '"'
}

rc_claim() { # $1 = repo root, $2 = item number. Prints "status<TAB>evidence ids<TAB>note". Prints nothing when no claim exists.
  cf=$(rc_claims_file "$1")
  [ -f "$cf" ] || return 0
  awk -F'|' -v n="$2" '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    trim($1) == n { print tolower(trim($2)) "\t" trim($3) "\t" trim($4); exit }' "$cf"
}

# Prints one problem for each DONE WHEN item that is not verified. Prints nothing when all items are verified.
rc_problems() { # $1 = repo root
  f=$(rc_file "$1")
  [ -f "$f" ] || return 0
  items=$(rc_section "$f" "DONE WHEN")
  if [ -z "$items" ]; then
    printf 'The contract has no DONE WHEN item.\n'
    return 0
  fi
  i=0
  while IFS= read -r text; do
    i=$((i + 1))
    claim=$(rc_claim "$1" "$i")
    if [ -z "$claim" ]; then printf 'Item %s has no claim: %s\n' "$i" "$text"; continue; fi
    st=$(printf '%s' "$claim" | cut -f1)
    ids=$(printf '%s' "$claim" | cut -f2)
    note=$(printf '%s' "$claim" | cut -f3)
    case $st in
      done)
        if [ -z "$ids" ]; then printf 'Item %s is claimed done with no evidence id: %s\n' "$i" "$text"; continue; fi
        for id in $(printf '%s' "$ids" | tr ',' ' '); do
          code=$(rc_evidence_exit "$1" "$id")
          if [ -z "$code" ]; then printf 'Item %s cites the evidence id %s. It is not in .real/evidence.jsonl.\n' "$i" "$id"
          elif [ "$code" != 0 ] && [ "$code" != unknown ]; then printf 'Item %s cites the evidence id %s. That command failed (exit %s).\n' "$i" "$id" "$code"
          fi
        done
        ;;
      could-not-measure)
        [ -n "$note" ] || printf 'Item %s is "could-not-measure" with no verifier. Name who can verify it.\n' "$i"
        ;;
      *) printf 'Item %s has the status "%s". Use done or could-not-measure.\n' "$i" "$st" ;;
    esac
  done <<RC_ITEMS
$items
RC_ITEMS
}

# Prints the Claimed and Verified table and the verdict.
rc_report() { # $1 = repo root
  f=$(rc_file "$1")
  [ -f "$f" ] || { printf 'No contract in %s.\n' "$1"; return 1; }
  task=$(rc_header "$f" Task)
  items=$(rc_section "$f" "DONE WHEN")
  printf 'Task: %s\n\n' "$task"
  printf '| # | DONE WHEN item | Claimed | Verified (evidence id) | Status |\n|---|---|---|---|---|\n'
  i=0; nv=0; nu=0; nc=0
  while IFS= read -r text; do
    [ -n "$text" ] || continue
    i=$((i + 1))
    claim=$(rc_claim "$1" "$i")
    st=$(printf '%s' "$claim" | cut -f1)
    ids=$(printf '%s' "$claim" | cut -f2)
    note=$(printf '%s' "$claim" | cut -f3)
    probs=$(rc_problems_item "$1" "$i" "$st" "$ids" "$note")
    if [ -z "$st" ]; then claimed=no; verified=-; status=unverified; nu=$((nu + 1))
    elif [ "$st" = could-not-measure ] && [ -z "$probs" ]; then claimed="could not measure"; verified="- ($note)"; status="could not measure"; nc=$((nc + 1))
    elif [ -z "$probs" ]; then claimed=yes; verified=$ids; status=verified; nv=$((nv + 1))
    else claimed=yes; verified=${ids:--}; status=unverified; nu=$((nu + 1))
    fi
    printf '| %s | %s | %s | %s | %s |\n' "$i" "$text" "$claimed" "$verified" "$status"
  done <<RC_ITEMS
$items
RC_ITEMS
  if [ "$nu" -eq 0 ] && [ "$nv" -gt 0 ]; then verdict=verified
  elif [ "$nv" -eq 0 ]; then verdict="not verified"
  else verdict="partly verified"; fi
  printf '\nVerdict: %s (%s verified, %s unverified, %s could not measure)\n' "$verdict" "$nv" "$nu" "$nc"
}

rc_problems_item() { # $1 root, $2 number, $3 status, $4 ids, $5 note. Prints a problem when the item is not verified.
  case $3 in
    done)
      [ -n "$4" ] || { printf 'no evidence\n'; return 0; }
      for id in $(printf '%s' "$4" | tr ',' ' '); do
        code=$(rc_evidence_exit "$1" "$id")
        if [ -z "$code" ]; then printf 'unknown id\n'; return 0; fi
        if [ "$code" != 0 ] && [ "$code" != unknown ]; then printf 'failed\n'; return 0; fi
      done
      ;;
    could-not-measure) [ -n "$5" ] || printf 'no verifier\n' ;;
    '') printf 'no claim\n' ;;
    *) printf 'bad status\n' ;;
  esac
}
