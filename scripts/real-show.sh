#!/bin/sh
# real-show.sh: print a verified link to a local file, folder or URL. Open only safe targets.
#
# Usage:
#   real-show.sh [--open] [--serve] [--title TEXT] [--root DIR] PATH
#   real-show.sh [--open] --url URL
#   real-show.sh --list
#   real-show.sh --stop [PORT|all]
#
# A folder or a file gives a file:// link. A web file (.html .htm .xhtml .svg) or any file with
# --serve gives an http://127.0.0.1:PORT link. A python3 server serves the root folder (default:
# the folder of the file). curl checks the link: the page title for a web file, the size for
# another file. --open runs "open -g PATH" on macOS for a folder or a file. It never opens a web
# page or a URL. --list prints PORT PID ROOT for each live server. --stop ends one or all servers.
#
# Exit codes: 0 ok, 2 bad input, 3 title or size mismatch, 4 a helper failed.
# State folder: ${XDG_STATE_HOME:-$HOME/.local/state}/real/show/ (one file for each server, named PORT).

set -f
umask 077
unset CDPATH

die() { printf 'real-show: %s\n' "$2" >&2; exit "$1"; }
cu() { curl -sS --noproxy '*' "$@"; }
nap() { sleep 0.1 2>/dev/null || sleep 1; }

# The one percent encoder. It keeps A-Z a-z 0-9 - . _ ~ / and writes every other byte as %XX.
pct() {
  printf '%s' "$1" | od -An -v -tu1 | awk 'BEGIN { for (i = 0; i < 256; i++) h[i] = sprintf("%02X", i) }
    { for (i = 1; i <= NF; i++) { c = $i
        if (c == 45 || c == 46 || c == 47 || c == 95 || c == 126 || (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122)) printf "%c", c
        else printf "%%%s", h[c] } }'
}
label() { printf '%s' "$1" | tr '[:cntrl:]' '?' | sed 's/[][\]/\\&/g'; }

# Python handler code. The server serves ROOT only, refuses dot names, key names and links that
# leave ROOT, and never lists a folder. argv: marker, port, root.
handler='import http.server, os, sys
root = os.path.realpath(sys.argv[3])
def bad(n):
    return (n[:1] == "." and n != ".") or n.startswith(("id_rsa", "id_ed25519")) or n.endswith((".pem", ".key"))
class H(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=root, **k)
    def log_message(self, *a):
        pass
    def list_directory(self, p):
        self.send_error(404)
    def send_head(self):
        p = self.translate_path(self.path)
        for q in (p, os.path.realpath(p)):
            if any(bad(n) for n in os.path.relpath(q, root).split(os.sep)):
                self.send_error(404)
                return None
        return super().send_head()
http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[2])), H).serve_forever()'
freeport='import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])'
# The one title extractor, for the local file and for the served page.
extract='import re, sys
m = re.search(r"<title[^>]*>(.*?)</title>", sys.stdin.buffer.read().decode("utf-8", "replace"), re.I | re.S)
sys.stdout.buffer.write((" ".join(m.group(1).split()) if m else "").encode() + b"\n")'
title_of() { python3 -c "$extract"; }

state=${XDG_STATE_HOME:-$HOME/.local/state}/real/show
ports() { ls "$state" 2>/dev/null | grep -E '^[0-9]+$' | sort -n; }
get() { sed -n "s/^$2=//p" "$state/$1" 2>/dev/null | head -n 1; }

# PID check. Never signal a PID before this passes: the PID is alive and runs "real-show-server PORT".
pid_ok() {
  case $1 in ''|*[!0-9]*|0) return 1 ;; esac
  kill -0 "$1" 2>/dev/null || return 1
  a=" $(ps -ww -p "$1" -o args= 2>/dev/null | tr '\n' ' ') "
  case $a in *" real-show-server "*) case $a in *" $2 "*) return 0 ;; esac ;; esac
  return 1
}
alive() { case $(ps -p "$1" -o stat= 2>/dev/null) in ''|Z*) return 1 ;; esac; }

# Stop the server of an entry when the PID check passes. The entry is always removed.
stop_entry() {
  pid=$(get "$1" pid); rc=1
  if pid_ok "$pid" "$1"; then
    kill "$pid" 2>/dev/null
    i=0; while pid_ok "$pid" "$1" && [ "$i" -lt 30 ]; do i=$((i + 1)); nap; done
    pid_ok "$pid" "$1" || wait "$pid" 2>/dev/null
    rc=0
  fi
  rm -f "$state/$1"
  return $rc
}

# Up to 10 s. 0: our server answers. 1: it died, or another process holds the port. 2: timeout.
wait_up() {
  end=$(($(date +%s) + 10))
  while [ "$(date +%s)" -le "$end" ]; do
    if cu -o /dev/null --max-time 1 "http://127.0.0.1:$2/" 2>/dev/null; then pid_ok "$1" "$2"; return; fi
    alive "$1" || return 1
    nap
  done
  return 2
}

# Start a server for $root. Sets port and pid, then writes the entry (only after the server answers).
start_server() {
  mkdir -p "$state" && chmod 700 "$state" || die 4 "cannot make the state folder"
  tries=0
  while [ "$tries" -lt 5 ]; do
    tries=$((tries + 1))
    port=$(python3 -c "$freeport" 2>/dev/null)
    case $port in ''|*[!0-9]*) die 4 "cannot read a free port" ;; esac
    # Race: another process can take the port before the server binds it. Then the server dies and we retry.
    nohup python3 -c "$handler" real-show-server "$port" "$root" </dev/null >/dev/null 2>&1 &
    pid=$!
    wait_up "$pid" "$port"; up=$?
    if [ "$up" = 0 ]; then
      printf 'pid=%s\nport=%s\nroot=%s\n' "$pid" "$port" "$root" > "$state/$port"
      return 0
    fi
    pid_ok "$pid" "$port" && kill "$pid" 2>/dev/null
    [ "$up" = 2 ] && die 4 "server start timeout"
  done
  die 4 "server did not start"
}

# Check the served URL of $rel. Sets vmsg on a mismatch. A web file needs the same title; another file the same size.
verify() {
  u=http://127.0.0.1:$port/$enc
  if [ -n "$want" ]; then
    got=$(cu -f --max-time 5 "$u" 2>/dev/null | title_of)
    [ "$got" = "$want" ] || { vmsg="title mismatch: expected \"$want\", got \"$got\""; return 1; }
  else
    r=$(cu --max-time 30 -o /dev/null -w '%{http_code} %{size_download}' "$u" 2>/dev/null)
    n=$(wc -c < "$real" | tr -d ' ')
    [ "$r" = "200 $n" ] || { vmsg="size mismatch: expected 200 $n, got $r"; return 1; }
  fi
}

find_entry() { for p in $(ports); do [ "$(get "$p" root)" = "$1" ] && { printf '%s\n' "$p"; return 0; }; done; return 1; }

# Fully resolved absolute path of an existing file (follows links; the file part too).
resolve() {
  p=$1
  while [ -L "$p" ]; do
    l=$(readlink "$p")
    case $l in /*) p=$l ;; *) p=$(dirname -- "$p")/$l ;; esac
  done
  d=$(cd "$(dirname -- "$p")" && pwd -P) || return 1
  printf '%s\n' "${d%/}/$(basename -- "$p")"
}

# Refuse a root that is too wide, or that holds secret names (unless the user named the root).
refuse_root() {
  [ "$root" = / ] && die 2 "refused root: /"
  case ${home:-/nonexistent}/ in "$root"/*) die 2 "refused root: your home folder or a parent of it: $root" ;; esac
  [ "$explicit" = 1 ] && return 0
  [ -z "$(find "$root"/. ! -name . -prune \( -name .git -o -name .env -o -name '.env.*' -o -name id_rsa -o -name id_ed25519 -o -name '*.pem' -o -name '*.key' \) -print | head -n 1)" ] \
    || die 2 "refused root: it holds .git, .env, a key or a certificate file. Use --root to choose it on purpose"
}

# The --open step. It runs after the link is printed. Only a folder or a file is ever opened, and only on macOS.
finish() { # finish web|local ABSOLUTE_PATH
  [ "$open" = 1 ] || exit 0
  if [ "$1" = web ]; then printf '%s\n' 'web page: link only'; exit 0; fi
  [ "${REAL_SHOW_OS:-$(uname -s)}" = Darwin ] || { printf '%s\n' 'not macOS: link only'; exit 0; }
  open -g "$2" >/dev/null 2>&1 || die 4 'open failed'
  exit 0
}

link_local() { printf '[%s](file://%s)\n' "$(label "$name")" "$(pct "$1")"; finish local "$1"; }

show_url() {
  case $url in *[[:space:][:cntrl:]\"\'\<\>\`]*) die 2 "bad URL: it holds a blank, a control character or a quote" ;; esac
  case $url in http://*|https://*) ;; *) die 2 "bad URL: only http and https are allowed" ;; esac
  h=${url#*://}; h=${h%%[/?#]*}
  [ -n "$h" ] || die 2 "bad URL: no host"
  printf '[%s](%s)\n' "$(label "$url")" "$(printf '%s' "$url" | sed -e 's/(/%28/g' -e 's/)/%29/g')"
  finish web
}

serve_file() {
  real=$(resolve "$path") || die 2 "cannot resolve: $path"
  home=$(cd "${HOME:-/nonexistent}" 2>/dev/null && pwd -P)
  if [ -n "$root" ]; then
    explicit=1
    root=$(cd "$root" 2>/dev/null && pwd -P) || die 2 "the root is not a folder: $root"
  else
    explicit=0
    root=$(dirname -- "$real")
  fi
  refuse_root
  case $real in "$root"/*) ;; *) die 2 "the file is not inside the root: $root" ;; esac
  command -v python3 >/dev/null 2>&1 || die 4 "python3 not found"
  command -v curl >/dev/null 2>&1 || die 4 "curl not found"
  enc=$(pct "${real#"$root"/}")
  want=; [ "$web" = 1 ] && want=$(title_of < "$real") # reuse and the new server are checked with the file's own title
  ok=0 started=0
  port=$(find_entry "$root")
  if [ -n "$port" ]; then
    if pid_ok "$(get "$port" pid)" "$port" && verify; then ok=1; else stop_entry "$port"; fi
  fi
  if [ "$ok" = 0 ]; then
    start_server; started=1
    verify || { stop_entry "$port"; die 3 "$vmsg"; }
  fi
  # --title is checked last. A wrong value stops only a server that this call started.
  if [ "$web" = 1 ] && [ -n "$title" ]; then
    want=$title
    verify || { [ "$started" = 1 ] && stop_entry "$port"; die 3 "$vmsg"; }
  fi
  printf '[%s](http://127.0.0.1:%s/%s)\n' "$(label "$name")" "$port" "$enc"
  if [ "$web" = 1 ]; then finish web; else finish local "$abs"; fi
}

show_path() {
  [ -n "$path" ] || die 2 "no PATH. Usage: real-show.sh [--open] [--serve] [--title TEXT] [--root DIR] PATH | --url URL | --list | --stop [PORT|all]"
  [ -e "$path" ] || die 2 "not found: $path"
  if [ -d "$path" ]; then
    [ "$serve" = 0 ] || die 2 "--serve needs a file"
    abs=$(cd "$path" && pwd -P) || die 2 "cannot enter: $path"
    name=$(basename -- "$abs")
    link_local "$abs"
  fi
  name=$(basename -- "$path")
  d=$(cd "$(dirname -- "$path")" && pwd -P) || die 2 "cannot enter the folder of: $path"
  abs=${d%/}/$name
  web=0
  case $(printf '%s' "$name" | tr 'A-Z' 'a-z') in *.html|*.htm|*.xhtml|*.svg) web=1 ;; esac
  [ "$web" = 1 ] || [ "$serve" = 1 ] || link_local "$abs"
  serve_file
}

stop_one() {
  pid=$(get "$1" pid)
  if stop_entry "$1"; then printf 'stopped %s\n' "$1"
  else printf 'real-show: refused to stop pid %s on port %s: not a real-show server\n' "$pid" "$1" >&2; fi
}

do_stop() {
  case $1 in
    all) for p in $(ports); do stop_one "$p"; done ;;
    *[!0-9]*) die 2 "bad port: $1" ;;
    *) [ -f "$state/$1" ] || die 2 "no server from real-show on port $1"; stop_one "$1" ;;
  esac
}

do_list() {
  for p in $(ports); do
    pid=$(get "$p" pid)
    if pid_ok "$pid" "$p"; then printf '%s %s %s\n' "$p" "$pid" "$(get "$p" root)"; else rm -f "$state/$p"; fi
  done
}

open=0 serve=0 title= root= url= path= mode=show stopto=all
while [ $# -gt 0 ]; do
  case $1 in
    --open) open=1 ;;
    --serve) serve=1 ;;
    --list) mode=list ;;
    --stop) mode=stop; case ${2:-} in ''|-*) ;; *) stopto=$2; shift ;; esac ;;
    --title|--root|--url)
      [ $# -ge 2 ] && [ -n "$2" ] || die 2 "$1 needs a value"
      case $1 in --title) title=$2 ;; --root) root=$2 ;; --url) mode=url; url=$2 ;; esac
      shift ;;
    -*) die 2 "unknown flag: $1" ;;
    *) [ -z "$path" ] || die 2 "only one PATH is allowed"; path=$1 ;;
  esac
  shift
done
[ "$mode" = show ] || [ -z "$path" ] || die 2 "unexpected argument: $path"

case $mode in
  list) do_list ;;
  stop) do_stop "$stopto" ;;
  url) show_url ;;
  *) show_path ;;
esac
