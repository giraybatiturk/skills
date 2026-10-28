# real-hooks-managed
# Engine of the approvals table. Source this file. Do not run it.
# It never reads standard input, so the hook and scripts/real-approvals.sh can both source it.
# POSIX sh. The awk code uses no GNU extension. It runs in mawk, BWK awk (macOS) and gawk.
# Records between the shell and awk. Fields are split by \001 and alternatives by \002 (a table cannot hold these bytes):
#   P path | E path line message | F path rule-count | R line id kind mode why alternatives | G id minutes-left | T tool name
# Single quotes are not allowed inside the awk programs, so they use "\047".

RA_MAX_BYTES=131072

# ---------- the awk programs ----------

# Shared by the matcher, the report and the export. The state text is the P, E, F, R, G and T records.
RA_AWK_COMMON='
function rank(m) { return (m == "deny" ? 3 : (m == "ask" ? 2 : 1)) }

# Glob test. "*" is any text, "?" is one character, every other character is literal. No regex.
# The text s is split once: BWK awk reads a whole string for each substr call, so a long word would cost O(n^2).
function glob(p, s,    np, ns, pi, si, star, mark, pc, S) {
  np = length(p); ns = split(s, S, ""); pi = 1; si = 1; star = 0; mark = 0
  while (si <= ns) {
    pc = substr(p, pi, 1)
    if (pi <= np && pc == "*") { star = pi; pi++; mark = si }
    else if (pi <= np && (pc == "?" || pc == S[si])) { pi++; si++ }
    else if (star) { pi = star + 1; mark++; si = mark }
    else return 0
  }
  while (pi <= np && substr(p, pi, 1) == "*") pi++
  return (pi > np)
}

# Glob to regex for the command matcher. Every regex character is escaped.
function g2r(p,    i, n, c, r) {
  n = length(p); r = ""
  for (i = 1; i <= n; i++) {
    c = substr(p, i, 1)
    if (c == "*") r = r ".*"
    else if (c == "?") r = r "."
    else if (index("\\.[](){}+|^$", c)) r = r "\\" c
    else r = r c
  }
  return r
}

# The write verb of an MCP tool name, or "". The tool part is the text after the second "__".
function wverb(name,    r, k, t, i, n, c, p, s, w, nw) {
  if (substr(name, 1, 5) != "mcp__") return ""
  r = substr(name, 6); k = index(r, "__")
  t = (k ? substr(r, k + 2) : r)
  n = length(t); s = ""; p = ""
  for (i = 1; i <= n; i++) {
    c = substr(t, i, 1)
    if (c ~ /[A-Z]/ && p ~ /[a-z0-9]/) s = s " "
    s = s c; p = c
  }
  s = tolower(s); gsub(/[^a-z0-9]+/, " ", s)
  nw = split(s, w, " ")
  for (i = 1; i <= nw; i++) if (index(VERBS, " " w[i] " ")) return w[i]
  return ""
}

function load(text,    n, i, F, na, A, j, p, fw, k) {
  n = split(text, LN, "\n")
  for (i = 1; i <= n; i++) {
    split(LN[i], F, SEP)
    if (F[1] == "T") tool = F[2]
    else if (F[1] == "P") fpath[++nf] = F[2]
    else if (F[1] == "F") fcount[F[2]] = F[3]
    else if (F[1] == "E") { ne++; epath[ne] = F[2]; eline[ne] = F[3]; emsg[ne] = F[4] }
    else if (F[1] == "G") { if (F[3] ~ /^[0-9]+$/) granted[F[2]] = F[3] }
    else if (F[1] == "R") {
      nr++; rid[nr] = F[3]; rkind[nr] = F[4]; rmode[nr] = F[5]; rwhy[nr] = F[6]; ralts[nr] = F[7]
      rpat[nr] = F[7]; gsub(ALT, "|", rpat[nr])
      na = split(F[7], A, ALT)
      for (j = 1; j <= na; j++) {
        nalt++; altrule[nalt] = nr; alttext[nalt] = A[j]
        if (F[4] == "command") {
          ncalt++
          p = tolower(A[j]); gsub(/ /, SEP, p)
          altrx[nalt] = SEP "\\\\?([^" SEP "]*/)?" g2r(p) SEP
          fw = p; k = index(p, SEP); if (k) fw = substr(p, 1, k - 1)
          if (fw ~ /[*?]/) { un[++nun] = nalt; ufw[nun] = fw }
          else ix[fw] = ix[fw] " " nalt
        }
      }
    }
  }
}
'

# The parser. It reads valid-looking files and prints E, R and F records. A file with an error prints no R record.
RA_AWK_PARSE='
BEGIN { SEP = "\001"; ALT = "\002"; Q = "\047" }
FNR == 1 { if (fname != "") fin(); fname = FILENAME; startfile(); sub(/^\357\273\277/, "") }
{ doline($0, FNR) }
END { if (fname != "") fin() }

function startfile() { ne = 0; nrt = 0; nbuf = 0; inr = 0; skip = 0; split("", seenid); split("", EL); split("", EM); split("", BUF) }
function err(ln, msg) { ne++; EL[ne] = ln + 0; EM[ne] = msg }

function doline(line, ln,    h, v, n) {
  sub(/\r$/, "", line)
  if (line ~ /^[ \t]*$/ || line ~ /^[ \t]*#/) return
  if (line ~ /^[ ]*\t/) { err(ln, "tab in the indentation"); return }
  if (match(line, /^-[ ]+[A-Za-z_][A-Za-z0-9_-]*:/)) {
    n = RLENGTH; h = substr(line, 1, n); v = substr(line, n + 1)
    if (inr) endrule()
    newrule(ln)
    setkey(h, v, ln)
  } else if (match(line, /^  +[A-Za-z_][A-Za-z0-9_-]*:/)) {
    n = RLENGTH; h = substr(line, 1, n); v = substr(line, n + 1)
    if (!inr) err(ln, "key outside a rule")
    else setkey(h, v, ln)
  } else err(ln, "line is not a comment, a rule start or a key")
}

function newrule(ln) {
  inr = 1; rl = ln; split("", HAVE); split("", V); split("", KL)
  nrt++; skip = (nrt > 500)
  if (nrt == 501) err(ln, "more than 500 rules")
}

function setkey(h, v, ln,    f) {
  sub(/^-?[ ]+/, "", h); sub(/:$/, "", h)
  sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
  if (length(v) > 500) { err(ln, "value over 500 characters"); v = substr(v, 1, 500) }
  if (length(v) >= 2) { f = substr(v, 1, 1); if ((f == "\"" || f == Q) && substr(v, length(v), 1) == f) v = substr(v, 2, length(v) - 2) }
  if (h !~ /^(id|tool|command|mode|why)$/) { err(ln, "unknown key " h); return }
  if (h in HAVE) { err(ln, "duplicate key " h); return }
  HAVE[h] = 1; V[h] = v; KL[h] = ln
}

function endrule(    id, kind, na, A, i, a, alts, ok) {
  inr = 0
  if (skip) return
  if (!("id" in HAVE)) err(rl, "missing id")
  if (!("mode" in HAVE)) err(rl, "missing mode")
  if (!("why" in HAVE)) err(rl, "missing why")
  else if (V["why"] == "") err(KL["why"], "missing why (the value is empty)")
  id = V["id"]
  if ("id" in HAVE) {
    if (id !~ /^[a-z0-9][a-z0-9-]*$/ || length(id) > 64) err(KL["id"], "bad id (use a-z, 0-9 and -, at most 64 characters)")
    else if (id == "none" || id == "default-write" || id == "broken-table") err(KL["id"], "reserved id " id)
    else if (id in seenid) err(KL["id"], "duplicate id " id " (first at line " seenid[id] ")")
    else seenid[id] = KL["id"]
  }
  if (("mode" in HAVE) && V["mode"] !~ /^(auto|ask|deny)$/) err(KL["mode"], "bad mode (use auto, ask or deny)")
  if (!(("tool" in HAVE) || ("command" in HAVE))) { err(rl, "no tool and no command"); return }
  if (("tool" in HAVE) && ("command" in HAVE)) { err(KL["tool"], "both tool and command"); return }
  kind = (("tool" in HAVE) ? "tool" : "command")
  na = split(V[kind], A, /[|]/)
  if (V[kind] == "") { err(KL[kind], "empty " kind " value"); return }
  if (na > 20) err(KL[kind], "too many alternatives (at most 20)")
  alts = ""; ok = 1
  for (i = 1; i <= na; i++) {
    a = A[i]; sub(/^[ \t]+/, "", a); sub(/[ \t]+$/, "", a)
    if (kind == "command") gsub(/[ \t]+/, " ", a)
    if (a == "") { err(KL[kind], "empty alternative in " kind); ok = 0 }
    else if (kind == "tool" && a !~ /^[A-Za-z0-9_.:*?-]+$/) { err(KL[kind], "bad tool alternative " a " (allowed: letters, digits and _ . : * ? -)"); ok = 0 }
    alts = alts (i > 1 ? ALT : "") a
  }
  if (!ok || ("mode" in HAVE) == 0 || ("why" in HAVE) == 0 || ("id" in HAVE) == 0) return
  BUF[++nbuf] = "R" SEP rl SEP id SEP kind SEP V["mode"] SEP V["why"] SEP alts
}

function fin(    i, j, tl, tm) {
  if (inr) endrule()
  for (i = 2; i <= ne; i++) {
    tl = EL[i]; tm = EM[i]; j = i - 1
    while (j >= 1 && EL[j] > tl) { EL[j + 1] = EL[j]; EM[j + 1] = EM[j]; j-- }
    EL[j + 1] = tl; EM[j + 1] = tm
  }
  for (i = 1; i <= ne; i++) print "E" SEP fname SEP EL[i] SEP EM[i]
  if (ne == 0) {
    for (i = 1; i <= nbuf; i++) print BUF[i]
    print "F" SEP fname SEP nbuf
  }
}
'

# The matcher. Record 1 is the state text (T, P, E, F, R, G). Record 2 is the command text.
# It prints 7 lines: mode, id, why, minutes left of a grant (or empty), and the path, line and message of the first error.
RA_AWK_MATCH='
BEGIN {
  RS = "\003"; SEP = "\001"; ALT = "\002"
  VERBS = " create update delete send post publish move merge remove add set edit write comment submit share upload archive deploy "
  SP = " \t\r\n;|&()`$\"\047\\"
}
NR == 1 { load($0) }
NR == 2 { cmd = $0 }
END { run() }

function consider(mode, id, why, gr,    s) {
  s = rank(mode)
  if (s > best) { best = s; bmode = mode; bid = id; bwhy = why; bgr = gr }
}

function run(    i, a, g, w, mode) {
  if (tool == "Bash" && cmd != "" && ncalt > 0) { budget = 2 * length(cmd) + 65536; scan(cmd, 1) }
  for (a = 1; a <= nalt; a++) if (rkind[altrule[a]] == "tool" && !tm[altrule[a]] && glob(alttext[a], tool)) tm[altrule[a]] = 1
  for (i = 1; i <= nr; i++) {
    if (rkind[i] == "tool") { if (!tm[i]) continue; toolhit = 1 }
    else if (!cm[i]) continue
    mode = rmode[i]; g = ""
    if (mode == "ask" && (rid[i] in granted)) { mode = "auto"; g = granted[rid[i]] }
    consider(mode, rid[i], rwhy[i], g)
  }
  if (toolong) consider("ask", "broken-table", "The command is too long or too nested to check. Split it into smaller commands.", "")
  w = wverb(tool)
  if (ne > 0 && w != "") consider("ask", "broken-table", "", "")
  else if (!toolhit && w != "") {
    g = ("default-write" in granted) ? granted["default-write"] : ""
    consider(g == "" ? "ask" : "auto", "default-write", "The tool name has the write verb " w " and no rule in the approvals table.", g)
  }
  if (best == 0) { bmode = "auto"; bid = "none"; bwhy = "No rule matches."; bgr = "" }
  print bmode; print bid; print bwhy; print bgr
  print (ne > 0 ? epath[1] : ""); print (ne > 0 ? eline[1] : ""); print (ne > 0 ? emsg[1] : "")
}

# The text of CH[a..b]. BWK awk reads a whole string for each substr call and copies a whole word for each append.
# So the command is split into characters once, and a run is joined in halves (O(n log n) for one long word).
function join(CH, a, b,    m, r, k) {
  if (b - a < 64) { r = ""; for (k = a; k <= b; k++) r = r CH[k]; return r }
  m = int((a + b) / 2)
  return join(CH, a, m) join(CH, m + 1, b)
}

# Index of the ")" that closes "$(". CH holds the n characters. i is the first character after "$(".
function close_paren(CH, n, i,    d, c, j) {
  d = 1
  while (i <= n) {
    c = CH[i]
    if (c == "\\") i++
    else if (c == "\047") { j = i + 1; while (j <= n && CH[j] != "\047") j++; i = j }
    else if (c == "\"") {
      i++
      while (i <= n && CH[i] != "\"") { if (CH[i] == "\\") i++; i++ }
    }
    else if (c == "(") d++
    else if (c == ")" && --d == 0) return i
    i++
  }
  return n + 1
}

function close_tick(CH, n, i) {
  while (i <= n && CH[i] != "`") { if (CH[i] == "\\") i++; i++ }
  return (i > n ? n + 1 : i)
}

# An "&" splits unless it belongs to a redirect: >& <& &>
function splits(CH, i,    p) {
  p = CH[i - 1]
  return (!(p == ">" || p == "<" || CH[i + 1] == ">"))
}

# Split the text into segments and words outside quotes. Every read is from the split characters (linear time).
# Outside quotes a "$" directly before a quote is dropped: $\047gh\047 and $"gh" are the word gh.
function scan(s, depth,    CH, n, i, c, w, inw, seg, nw, rs, j, ds) {
  if (depth > 4) return
  # A nested scan is skipped when a deny is known and the work is big: nothing can rank above a deny.
  if (depth > 1 && denied && work > 65536) return
  # Work budget: a nested scan that would pass it is skipped and the command gets an ask (see run). It stops the doubling of nested scans.
  if (work + length(s) > budget) { toolong = 1; return }
  work += length(s)
  n = split(s, CH, ""); i = 1; w = ""; inw = 0; seg = ""; nw = 0; rs = 0
  while (i <= n) {
    c = CH[i]
    if (!index(SP, c)) { if (!rs) rs = i; inw = 1; i++; continue }
    if (rs) { w = w join(CH, rs, i - 1); rs = 0 }
    if (c == "\047") {
      j = i + 1
      while (j <= n && CH[j] != "\047") j++
      w = w join(CH, i + 1, j - 1); inw = 1; i = j + 1
    } else if (c == "\"") {
      inw = 1; i++; ds = i
      while (i <= n && (c = CH[i]) != "\"") {
        if (c == "\\") { w = w join(CH, ds, i - 1) CH[i + 1]; i += 2; ds = i }
        else if (c == "$" && CH[i + 1] == "(") {
          w = w join(CH, ds, i - 1) "$"; j = close_paren(CH, n, i + 2)
          scan(join(CH, i + 2, j - 1), depth + 1); i = j + 1; ds = i
        }
        else if (c == "`") {
          w = w join(CH, ds, i - 1) "$"; j = close_tick(CH, n, i + 1)
          scan(join(CH, i + 1, j - 1), depth + 1); i = j + 1; ds = i
        }
        else i++
      }
      if (ds <= n) w = w join(CH, ds, i - 1)
      i++
    } else if (c == "\\") {
      if (CH[i + 1] != "\n") { w = w CH[i + 1]; inw = 1 }
      i += 2
    } else if (c == "$") {
      if (CH[i + 1] != "\047" && CH[i + 1] != "\"") { w = w c; inw = 1 }
      i++
    } else if (c == " " || c == "\t" || c == "\r") {
      if (inw) { seg = seg (nw++ ? SEP : "") w; w = ""; inw = 0 }
      i++
    } else if (c == ";" || c == "|" || c == "\n" || c == "(" || c == ")" || c == "`" || (c == "&" && splits(CH, i))) {
      if (inw) { seg = seg (nw++ ? SEP : "") w; w = ""; inw = 0 }
      seg_end(seg, nw, depth); seg = ""; nw = 0
      i++
    } else { w = w c; inw = 1; i++ }
  }
  if (rs) w = w join(CH, rs, n)
  if (inw) seg = seg (nw++ ? SEP : "") w
  seg_end(seg, nw, depth)
}

# One segment. Every word position is a start of a candidate: its basename in lower case, then the later words.
# The candidates are not built one by one. A pattern whose first word occurs in the segment is tested ONCE on the text
# SEP w1 SEP w2 ... SEP (lower case). altrx lets the first word carry a leading "\" and a folder part, so "/usr/bin/GH" and "\gh" count as gh.
# The nested scans (-c strings, eval text) come last, so a deny of this segment is known before them.
function seg_end(seg, nw, depth,    W, pos, i, p, f, FP, np, na, A, a, r, u, ev, LS, SF, SU) {
  if (!nw) return
  split(seg, W, SEP)
  LS = SEP tolower(seg) SEP
  for (i = 1; i <= nw; i++) {
    f = tolower(W[i]); sub(/^\\/, "", f)
    if (index(f, "/")) { np = split(f, FP, "/"); f = FP[np] }
    if (f == "" || (f in SF)) continue
    SF[f] = 1
    if (f in ix) {
      na = split(ix[f], A, " ")
      for (a = 1; a <= na; a++) { r = altrule[A[a]]; if (!cm[r] && LS ~ altrx[A[a]]) hit(r) }
    }
    for (u = 1; u <= nun; u++) {
      r = altrule[un[u]]
      if (!cm[r] && !(u in SU) && glob(ufw[u], f)) { SU[u] = 1; if (LS ~ altrx[un[u]]) hit(r) }
    }
  }
  p = 1
  for (i = 1; i <= nw; i++) { pos[i] = p; p += length(W[i]) + 1 }
  ev = 0
  for (i = 1; i <= nw; i++) {
    if (i < nw && W[i] ~ /^-[A-Za-z]*c[A-Za-z]*$/) scan(W[i + 1], depth + 1)
    if (!ev && W[i] == "eval" && i < nw) ev = i
  }
  if (ev) { r = substr(seg, pos[ev + 1]); gsub(SEP, " ", r); scan(r, depth + 1) }
}

function hit(r) { cm[r] = 1; if (rmode[r] == "deny") denied = 1 }
'

# The report of "check": one line for each file, one for each rule, and the conflicts. Exit 1 when a file has an error.
RA_AWK_REPORT='
BEGIN { RS = "\003"; SEP = "\001"; ALT = "\002"; VERBS = " " }
NR == 1 { load($0) }
END { report() }

function lit(a, kind) { if (kind == "tool") return a; a = tolower(a); gsub(/ /, SEP, a); return a }
function pm(p, c, kind) { return (kind == "tool" ? glob(p, c) : (glob(p, c) || glob(p SEP "*", c))) }

function report(    f, e, bad, i, j, k, l, na, nb, A, B, hit, text, kind, st, rc) {
  for (f = 1; f <= nf; f++) {
    bad = 0
    for (e = 1; e <= ne; e++) if (epath[e] == fpath[f]) { print fpath[f] ":" eline[e] ": " emsg[e]; bad = 1; rc = 1 }
    if (!bad) print fpath[f] ": ok (" ((fpath[f] in fcount) ? fcount[fpath[f]] : 0) " rules)"
  }
  for (i = 1; i <= nr; i++) print rid[i] "  " rmode[i] "  " rkind[i] "  " rpat[i]
  for (i = 1; i <= nr; i++) for (j = i + 1; j <= nr; j++) {
    if (rkind[i] != rkind[j] || rmode[i] == rmode[j]) continue
    kind = rkind[i]; hit = ""
    na = split(ralts[i], A, ALT); nb = split(ralts[j], B, ALT)
    for (k = 1; k <= na && hit == ""; k++) for (l = 1; l <= nb && hit == ""; l++) {
      if (pm(lit(A[k], kind), lit(B[l], kind), kind)) hit = B[l]
      else if (pm(lit(B[l], kind), lit(A[k], kind), kind)) hit = A[k]
    }
    if (hit != "") {
      st = (rank(rmode[i]) > rank(rmode[j]) ? rmode[i] : rmode[j])
      print "conflict: " rid[i] " (" rmode[i] ") and " rid[j] " (" rmode[j] ") both match \047" hit "\047. The stricter mode wins: " st "."
    }
  }
  exit rc + 0
}
'

# The export for omp. Record 1 is the state text. Record 2 is the list of tool names (one for each line), or no record 2.
RA_AWK_EXPORT='
BEGIN { RS = "\003"; SEP = "\001"; ALT = "\002"; VERBS = " create update delete send post publish move merge remove add set edit write comment submit share upload archive deploy " }
NR == 1 { load($0) }
NR == 2 { names = $0; havetools = 1 }
END { export() }

# Claude Code and Codex name: mcp__S__T. omp name: mcp__S_T (a tool name that repeats the server prefix is stripped).
function omp(n,    r, k, s, t) {
  r = substr(n, 6); k = index(r, "__")
  if (!k) return n
  s = substr(r, 1, k - 1); t = substr(r, k + 2)
  if (substr(t, 1, length(s) + 1) == s "_") t = substr(t, length(s) + 2)
  return "mcp__" s "_" t
}

function add(name, mode, id) {
  if (!(name in omode)) { omode[name] = mode; oid[name] = id; onames[++non] = name }
  else if (rank(mode) > rank(omode[name])) { omode[name] = mode; oid[name] = id }
}

function export(    f, e, i, a, na, A, t, nt, T, nonmcp, hit, j, k, tmp, name) {
  if (ne > 0) {
    for (f = 1; f <= nf; f++) for (e = 1; e <= ne; e++) if (epath[e] == fpath[f]) print fpath[f] ":" eline[e] ": " emsg[e]
    exit 1
  }
  nt = 0
  if (havetools) {
    k = split(names, T, "\n")
    for (i = 1; i <= k; i++) if (T[i] ~ /^[A-Za-z0-9_.:-]+$/) TL[++nt] = T[i]
  }
  for (i = 1; i <= nr; i++) {
    if (rmode[i] == "auto") continue
    if (rkind[i] == "command") { cm[++nc] = "# " rid[i] ": runs through the hook with REAL_ASK_MODE=deny"; continue }
    na = split(ralts[i], A, ALT); nonmcp = 0
    for (a = 1; a <= na; a++) {
      if (substr(A[a], 1, 5) != "mcp__") { nonmcp = 1; continue }
      if (A[a] ~ /[*?]/) {
        if (havetools) { for (t = 1; t <= nt; t++) if (glob(A[a], TL[t])) add(omp(TL[t]), rmode[i], rid[i]) }
        else cm[++nc] = "# " rid[i] ": " A[a] " needs exact tool names. Run export-omp --tools FILE."
      } else add(omp(A[a]), rmode[i], rid[i])
    }
    if (nonmcp) cm[++nc] = "# " rid[i] ": built-in tool names differ in omp. Set it by hand."
  }
  if (havetools) for (t = 1; t <= nt; t++) {
    if (substr(TL[t], 1, 5) != "mcp__" || wverb(TL[t]) == "") continue
    hit = 0
    for (a = 1; a <= nalt && !hit; a++) if (rkind[altrule[a]] == "tool" && glob(alttext[a], TL[t])) hit = 1
    if (!hit) add(omp(TL[t]), "ask", "default-write")
  }
  for (i = 2; i <= non; i++) {
    tmp = onames[i]; j = i - 1
    while (j >= 1 && onames[j] > tmp) { onames[j + 1] = onames[j]; j-- }
    onames[j + 1] = tmp
  }
  print "# omp tools.approval block from the approvals table. Merge it into the omp config by hand. This command writes no file."
  print "tools:"
  if (non == 0) print "  approval: {}"
  else {
    print "  approval:"
    for (i = 1; i <= non; i++) { name = onames[i]; print "    " name ": " (omode[name] == "deny" ? "deny" : "prompt") " # " oid[name] }
  }
  for (i = 1; i <= nc; i++) print cm[i]
}
'

# Secret masking, control characters, UTF-8 check and the 300 character cut. One line in, one line out.
RA_AWK_CLEAN='
function maskpre(s, re, plen, minlen,    o, t) {
  o = ""
  while (match(s, re)) {
    o = o substr(s, 1, RSTART - 1)
    t = substr(s, RSTART, RLENGTH)
    o = o ((RLENGTH - plen >= minlen) ? "[masked]" : t)
    s = substr(s, RSTART + RLENGTH)
  }
  return o s
}
function maskkv(s, key,    o, r, p, q, k) {
  o = ""; k = length(key)
  while ((p = index(tolower(s), key)) > 0) {
    o = o substr(s, 1, p + k - 1) "[masked]"
    r = substr(s, p + k); q = index(r, " ")
    s = (q ? substr(r, q) : "")
  }
  return o s
}
function maskjwt(s,    o, t, P, n) {
  o = ""
  while (match(s, /eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/)) {
    o = o substr(s, 1, RSTART - 1); t = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
    n = split(t, P, ".")
    o = o ((length(P[1]) - 3 >= 10 && length(P[2]) - 3 >= 10 && length(P[3]) >= 10) ? "[masked]" : t)
  }
  return o s
}
function maskkey(s,    o, r, q) {
  o = ""
  while (match(s, /-----BEGIN [A-Z ]*PRIVATE KEY-----/)) {
    o = o substr(s, 1, RSTART - 1) "[masked]"
    r = substr(s, RSTART + RLENGTH)
    if (match(r, /-----END [A-Z ]*PRIVATE KEY-----/)) s = substr(r, RSTART + RLENGTH); else s = ""
  }
  return o s
}
function utf8(s,    o, k) {
  o = ""
  while (s != "") {
    if (match(s, /^([\001-\177]+|[\302-\337][\200-\277]|[\340-\357][\200-\277][\200-\277]|[\360-\364][\200-\277][\200-\277][\200-\277])/)) { o = o substr(s, 1, RLENGTH); s = substr(s, RLENGTH + 1) }
    else { o = o "?"; s = substr(s, 2) }
  }
  return o
}
BEGIN {
  AKIA = "AKIA"; for (i = 0; i < 16; i++) AKIA = AKIA "[0-9A-Z]"
  AIZA = "AIza"; for (i = 0; i < 35; i++) AIZA = AIZA "[0-9A-Za-z_-]"
}
{
  s = $0
  s = maskkey(s)
  s = maskpre(s, "gh[pousr]_[A-Za-z0-9]+", 4, 20)
  s = maskpre(s, "github_pat_[A-Za-z0-9_]+", 11, 20)
  s = maskpre(s, AKIA, 0, 0)
  s = maskpre(s, "xox[baprs]-[A-Za-z0-9-]+", 5, 10)
  s = maskpre(s, "sk-[A-Za-z0-9_-]+", 3, 20)
  s = maskpre(s, "sk_live_[A-Za-z0-9]+", 8, 16)
  s = maskpre(s, AIZA, 0, 0)
  s = maskpre(s, "glpat-[A-Za-z0-9_-]+", 6, 20)
  s = maskjwt(s)
  s = maskkv(s, "password="); s = maskkv(s, "token="); s = maskkv(s, "secret="); s = maskkv(s, "api_key="); s = maskkv(s, "apikey=")
  gsub(/[\001-\037\177]/, "", s)
  s = utf8(s)
  if (length(s) > 300) {
    t = substr(s, 1, 300)
    if (substr(s, 301, 1) ~ /[\200-\277]/) { sub(/[\200-\277]*$/, "", t); sub(/[\300-\377]$/, "", t) }
    s = t "..."
  }
  print s
}
'

ra_parse() { LC_ALL=C awk "$RA_AWK_PARSE" "$@"; }
ra_clean() { LC_ALL=C awk "$RA_AWK_CLEAN"; } # text on stdin, cleaned lines on stdout

# ---------- tables ----------

ra_user_table() { printf '%s\n' "${XDG_CONFIG_HOME:-${HOME:-}/.config}/real/approvals.yml"; }

ra_repo_table() { printf '%s/.real/approvals.yml\n' "$1"; } # $1 = repo root

# The tables that apply, one path for each line (absolute). REAL_APPROVALS names the only table. Otherwise the repo table and the user table both apply.
ra_files() { # $1 = repo root
  if [ -n "${REAL_APPROVALS:-}" ]; then
    case $REAL_APPROVALS in /*) printf '%s\n' "$REAL_APPROVALS" ;; *) printf '%s/%s\n' "$PWD" "$REAL_APPROVALS" ;; esac
    return 0
  fi
  ra_r=$(ra_repo_table "$1")
  ra_u=$(ra_user_table)
  ra_have_r=0
  if [ -e "$ra_r" ] || [ -L "$ra_r" ]; then ra_have_r=1; printf '%s\n' "$ra_r"; fi
  if [ -e "$ra_u" ] || [ -L "$ra_u" ]; then
    if [ "$ra_have_r" = 1 ] && [ "$ra_u" -ef "$ra_r" ]; then :; else printf '%s\n' "$ra_u"; fi
  fi
}

# Prints a message when the file cannot be read as a table. Prints nothing when it can.
ra_precheck() { # $1 = file
  if [ ! -f "$1" ] || [ ! -r "$1" ]; then
    if [ -n "${REAL_APPROVALS:-}" ]; then printf 'REAL_APPROVALS points to a missing file\n'; else printf 'the table is not a readable regular file\n'; fi
    return 0
  fi
  if [ $(( $(wc -c < "$1") )) -gt "$RA_MAX_BYTES" ]; then printf 'the table is larger than %s bytes\n' "$RA_MAX_BYTES"; return 0; fi
  if ! LC_ALL=C tr -d '\000-\010\013\014\016-\037\177' < "$1" | cmp -s - "$1"; then printf 'the table holds a control byte\n'; fi
}

# Read the tables. Sets RA_FILES (paths), RA_REC (the state text) and RA_BROKEN (1 when one file has an error).
ra_load() { # $1 = repo root
  RA_FILES=$(ra_files "$1"); RA_REC=; RA_BROKEN=0
  [ -n "$RA_FILES" ] || return 0
  ra_head=; ra_ne=0
  set --
  while IFS= read -r ra_f; do
    ra_head=$ra_head$(printf 'P\001%s' "$ra_f")'
'
    ra_m=$(ra_precheck "$ra_f")
    if [ -n "$ra_m" ]; then
      ra_head=$ra_head$(printf 'E\001%s\001%s\001%s' "$ra_f" 0 "$ra_m")'
'
      RA_BROKEN=1
    else
      set -- "$@" "$ra_f"
      [ ! -s "$ra_f" ] || ra_ne=1
    fi
  done <<EOF
$RA_FILES
EOF
  ra_body=
  [ $# -eq 0 ] || ra_body=$(ra_parse "$@")
  if [ -z "$ra_body" ] && [ "$ra_ne" = 1 ]; then # awk failed: a table with text always gives a record
    ra_head=$ra_head$(printf 'E\001%s\001%s\001%s' "$1" 0 "the table could not be parsed. Check that awk works")'
'
    RA_BROKEN=1
  fi
  case $ra_body in E*|*'
E'*) RA_BROKEN=1 ;; esac
  RA_REC=$ra_head$ra_body
}

# ---------- grants ----------

ra_grant_dir() { printf '%s\n' "${XDG_STATE_HOME:-${HOME:-}/.local/state}/real/approvals"; }

# One line for each grant file. $1 = records: "G<SEP>id<SEP>minutes-left" for valid grants. $1 = list: "id minutes-left", "id expired" or "id invalid".
# A valid grant is a regular file (no link) that holds exactly one line expires=DIGITS, with an expiry in the future.
ra_grant_scan() { # $1 = records or list
  ra_d=$(ra_grant_dir)
  [ -d "$ra_d" ] || return 0
  ra_now=$(date +%s)
  ra_fmt=$1
  ls -1 "$ra_d" 2>/dev/null | while IFS= read -r ra_n; do
    case $ra_n in ''|*[!a-z0-9-]*|-*) continue ;; esac
    [ ${#ra_n} -le 64 ] || continue
    ra_p=$ra_d/$ra_n
    if [ ! -f "$ra_p" ] || [ -L "$ra_p" ]; then continue; fi
    ra_l1=; ra_l2=
    { IFS= read -r ra_l1 || :; if IFS= read -r ra_l2 || [ -n "$ra_l2" ]; then ra_l1=bad; fi; } < "$ra_p"
    ra_st=invalid
    case $ra_l1 in
      expires=0?*|expires=*[!0-9]*|expires=|bad) ;;
      expires=*)
        ra_e=${ra_l1#expires=}
        if [ ${#ra_e} -le 12 ]; then
          if [ "$ra_e" -gt "$ra_now" ]; then ra_st=$(( (ra_e - ra_now + 59) / 60 )); else ra_st=expired; fi
        fi ;;
    esac
    if [ "$ra_fmt" = list ]; then printf '%s %s\n' "$ra_n" "$ra_st"
    else case $ra_st in expired|invalid) ;; *) printf 'G\001%s\001%s\n' "$ra_n" "$ra_st" ;; esac
    fi
  done
}

# ---------- decision ----------

# Decide for one tool call. $1 = tool name, $2 = command text (used for Bash only).
# Sets RA_MODE (auto, ask, deny), RA_ID, RA_WHY (clean text), RA_GRANT (minutes left when a grant made it auto) and RA_BTXT (text about a broken file, or empty).
ra_decide() {
  ra_tool=$(printf '%s' "$1" | tr -d '\000-\037\177')
  ra_cmd=$(printf '%s' "$2" | tr -d '\001-\003')
  ra_out=$({
    printf 'T\001%s\n' "$ra_tool"
    printf '%s\n' "$RA_REC"
    ra_grant_scan records
    printf '\003'
    printf '%s' "$ra_cmd"
  } | LC_ALL=C awk "$RA_AWK_COMMON
$RA_AWK_MATCH")
  {
    IFS= read -r RA_MODE; IFS= read -r RA_ID; IFS= read -r RA_WHY; IFS= read -r RA_GRANT
    IFS= read -r ra_ep; IFS= read -r ra_el; IFS= read -r ra_em
  } <<EOF
$ra_out
EOF
  if [ -z "$RA_MODE" ]; then # awk failed: a tool that can change something asks (Codex: denies), a read-only tool gets a warning
    RA_GRANT=
    RA_WHY="The approvals engine gave no result. Check that awk works."
    RA_BTXT="the approvals engine gave no result. Check that awk works."
    case $ra_tool in mcp__*|Bash) RA_MODE=ask; RA_ID=broken-table ;; *) RA_MODE=auto; RA_ID=none ;; esac
    return 0
  fi
  RA_BTXT=
  if [ -n "$ra_ep" ]; then
    ra_ep=$(printf '%s' "$ra_ep" | ra_clean); ra_em=$(printf '%s' "$ra_em" | ra_clean)
    if [ "${ra_el:-0}" -gt 0 ] 2>/dev/null; then ra_er="line $ra_el: $ra_em"; else ra_er=$ra_em; fi
    RA_BTXT="the approvals table $ra_ep has an error ($ra_er). Run real-approvals.sh check."
    [ "$RA_ID" != broken-table ] || RA_WHY="The approvals table $ra_ep has an error: $ra_er. Run real-approvals.sh check."
  fi
  case $RA_ID in broken-table) ;; *) RA_WHY=$(printf '%s' "$RA_WHY" | ra_clean) ;; esac
}
