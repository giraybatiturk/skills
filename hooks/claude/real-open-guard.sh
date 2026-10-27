#!/bin/sh
# real-hooks-managed
# PreToolUse hook for the Bash tool. Works in Claude Code and in Codex.
# Deny (exit 2):  a direct open, xdg-open, gnome-open, kde-open, sensible-browser, x-www-browser, www-browser,
#                 python -m webbrowser, or a start of google-chrome, chromium or firefox that is not headless.
#                 The command word counts after VAR=value, sudo, command, exec, nohup, time and env.
#                 The scan also covers $( ), backticks and the string of sh -c, bash -c, zsh -c, dash -c.
# Allowed:        real-show.sh (also as "sh real-show.sh"), headless browsers, and any word inside quotes
#                 that is only text, such as a commit message.
# Never asks. The command cannot switch the guard off: REAL_OPEN_GUARD=off inside the command is denied.
# Switch it off in the environment of the hook, in .real-hooks (open.guard = off) or with git config real.hooks.open.guard.

. "$(dirname "$0")/lib.sh"
set -f

[ "$(rh_field tool_name)" = Bash ] || exit 0
cmd=$(rh_field command)
[ -n "$cmd" ] || exit 0
[ "$(rh_cfg open.guard)" = off ] && exit 0

# A small quote-aware scanner. It splits the command into segments at ; && || | & and newlines,
# reads the command word of each segment, and scans $( ), backtick and -c strings the same way (-c strings: 3 levels).
# The command comes on stdin: an environment string over 128 KiB would stop awk from starting and the guard would fail open.
verdict=$(printf '%s' "$cmd" | awk '
# The file system of macOS ignores case, so every name check uses the lower case basename.
function base(w) { sub(/.*\//, "", w); return tolower(w) }

# Index of the ")" that closes "$(". i is the first character after "$(".
function close_paren(s, i,    n, d, c, j) {
  n = length(s); d = 1
  while (i <= n) {
    c = substr(s, i, 1)
    if (c == "\\") i++
    else if (c == Q) { j = index(substr(s, i + 1), Q); i = (j ? i + j : n) }
    else if (c == "\"") {
      i++
      while (i <= n && substr(s, i, 1) != "\"") { if (substr(s, i, 1) == "\\") i++; i++ }
    }
    else if (c == "(") d++
    else if (c == ")" && --d == 0) return i
    i++
  }
  return n + 1
}

function close_tick(s, i,    n) {
  n = length(s)
  while (i <= n && substr(s, i, 1) != "`") { if (substr(s, i, 1) == "\\") i++; i++ }
  return (i > n ? n + 1 : i)
}

# An "&" splits unless it belongs to a redirect: >& <& &>
function splits(s, i,    p) {
  p = substr(s, i - 1, 1)
  return !(p == ">" || p == "<" || substr(s, i + 1, 1) == ">")
}

# Single-quote one word, so the text of a later word stays data when it is scanned again.
function sq(w,    o, p) {
  o = ""
  while ((p = index(w, Q)) > 0) { o = o substr(w, 1, p - 1) Q "\\" Q Q; w = substr(w, p + 1) }
  return Q o w Q
}

# One segment: words joined by SEP. Returns "" (fine), "D" (deny) or "C" and a -c string to scan.
function classify(seg,    n, i, j, b, k, s, r) {
  n = split(seg, W, SEP); i = 1
  while (i <= n) {
    b = base(W[i])
    if (W[i] ~ REDIR) i += (W[i] ~ REDIR_ONLY ? 2 : 1)
    else if (W[i] ~ /^[A-Za-z_][A-Za-z0-9_]*=/) i++
    else if (index(KEYWORDS, " " W[i] " ")) i++
    else if (b == "sudo") { i++; while (i <= n && W[i] ~ /^-/) i += (W[i] ~ SUDO_ARG ? 2 : 1) }
    else if (b == "env") {
      i++
      while (i <= n && (W[i] ~ /^-/ || W[i] ~ /^[A-Za-z_][A-Za-z0-9_]*=/)) {
        if (W[i] ~ /^-[^-uCaPS]*S/ || W[i] ~ /^--split-string(=|$)/) {
          # env -S STR runs STR as a command line. Scan "env STR rest" like a -c string.
          j = i + 1
          if (W[i] ~ /^--/) { if (index(W[i], "=")) s = substr(W[i], index(W[i], "=") + 1); else s = W[j++] }
          else { s = substr(W[i], index(W[i], "S") + 1); if (s == "") s = W[j++] }
          r = "env " s
          for (; j <= n; j++) r = r " " sq(W[j])
          return "C" r
        }
        i += (W[i] ~ ENV_ARG ? 2 : 1)
      }
    }
    else if (b == "command" || b == "exec" || b == "nohup" || b == "time") {
      i++
      while (i <= n && W[i] ~ /^-/) {
        if (b == "command" && W[i] ~ /^-[A-Za-z]*[vV]/) return ""
        if (b == "exec" && W[i] ~ /^-[A-Za-z]*a$/) i++
        i++
      }
    }
    else break
  }
  if (i > n) return ""
  b = base(W[i])
  if (b == "real-show.sh") return ""
  if (b ~ /^(sh|bash|dash|zsh)$/) {
    for (k = i + 1; k <= n; k++) {
      if (W[k] ~ /^-[A-Za-z]*c[A-Za-z]*$/) return "C" W[k + 1]
      if (W[k] !~ /^-/) return ""
    }
    return ""
  }
  if (index(OPENERS, " " b " ")) return "D"
  if (b == "gio") return (W[i + 1] == "open" ? "D" : "")
  if (b ~ /^python(3(\.[0-9]+)?)?$/) {
    for (k = i + 1; k <= n; k++) if (W[k] == "-mwebbrowser" || (W[k] == "-m" && W[k + 1] == "webbrowser")) return "D"
    return ""
  }
  if (index(BROWSERS, " " b " ") || b == "google chrome") {
    for (k = i + 1; k <= n; k++) if (W[k] ~ /^(--headless(=.*)?|-headless)$/) return ""
    return "D"
  }
  return ""
}

function end_seg(seg, nw, depth,    r) {
  if (!nw) return
  r = classify(seg)
  if (r == "D") denied = 1
  else if (r != "") scan(substr(r, 2), depth + 1)
}

function scan(s, depth,    n, i, c, j, w, seg, nw, inw) {
  if (depth > 4) return
  n = length(s); i = 1; w = ""; seg = ""; nw = 0; inw = 0
  while (i <= n && !denied) {
    c = substr(s, i, 1)
    if (c == Q) {
      j = index(substr(s, i + 1), Q); if (!j) j = n - i + 1
      w = w substr(s, i + 1, j - 1); inw = 1; i += j + 1
    } else if (c == "\"") {
      inw = 1; i++
      while (i <= n && substr(s, i, 1) != "\"") {
        c = substr(s, i, 1)
        if (c == "\\") { w = w substr(s, i + 1, 1); i += 2 }
        else if (c == "$" && substr(s, i + 1, 1) == "(") { j = close_paren(s, i + 2); scan(substr(s, i + 2, j - i - 2), depth); w = w "$"; i = j + 1 }
        else if (c == "`") { j = close_tick(s, i + 1); scan(substr(s, i + 1, j - i - 1), depth); w = w "$"; i = j + 1 }
        else { w = w c; i++ }
      }
      i++
    } else if (c == "\\") {
      if (substr(s, i + 1, 1) != "\n") { w = w substr(s, i + 1, 1); inw = 1 }
      i += 2
    } else if (c == "$" && substr(s, i + 1, 1) == "(") {
      j = close_paren(s, i + 2); scan(substr(s, i + 2, j - i - 2), depth); w = w "$"; inw = 1; i = j + 1
    } else if (c == "`") {
      j = close_tick(s, i + 1); scan(substr(s, i + 1, j - i - 1), depth); w = w "$"; inw = 1; i = j + 1
    } else if (c == " " || c == "\t") {
      if (inw) { seg = seg (nw++ ? SEP : "") w; w = ""; inw = 0 }
      i++
    } else if (c == "#" && !inw) {
      while (i <= n && substr(s, i, 1) != "\n") i++
    } else if (c == ";" || c == "|" || c == "\n" || c == "(" || c == ")" || (c == "&" && splits(s, i))) {
      if (inw) { seg = seg (nw++ ? SEP : "") w; w = ""; inw = 0 }
      end_seg(seg, nw, depth); seg = ""; nw = 0
      i++
    } else { w = w c; inw = 1; i++ }
  }
  if (inw) seg = seg (nw++ ? SEP : "") w
  end_seg(seg, nw, depth)
}

BEGIN {
  SEP = "\001"; Q = "\047"
  OPENERS = " open xdg-open gnome-open kde-open sensible-browser x-www-browser www-browser "
  BROWSERS = " google-chrome google-chrome-stable chromium chromium-browser chrome firefox "
  KEYWORDS = " ! { if then elif else do while until "
  SUDO_ARG = "^(-[A-Za-z]*[CDghpRrtTUu]|--(user|group|host|prompt|chdir|chroot|role|type|command-timeout|other-user|close-from))$"
  # An env option that takes the next word as its value (also in a cluster such as -ia).
  ENV_ARG = "^(--(unset|chdir|argv0)|-[^-uCaPS]*[uCaP])$"
  # A redirect word: optional fd number, then the operator. A word that is only the operator takes the next word as its target.
  REDIR = "^[0-9]*(<<<|<<-?|>>|<>|>&|<&|&>>|&>|>\\||<|>)"; REDIR_ONLY = REDIR "$"
}
{ s = s (NR > 1 ? "\n" : "") $0 }
END { scan(s, 1); print (denied ? "deny" : "ok") }' 2>/dev/null)

[ "$verdict" = deny ] && rh_block "direct open of a file, folder or browser is denied. Run real-show.sh --open PATH for a file or folder. For a web page, give the link only."
exit 0
