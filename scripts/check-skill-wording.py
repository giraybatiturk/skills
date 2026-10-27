#!/usr/bin/env python3
"""Meta check for a wording-only rewrite of the Real skills.

For every Markdown file under skills/*/*/ (SKILL.md and references/), compare the file
at a base git ref (default: origin/main) with the working tree. List every item that
carries behaviour in the base file, then confirm that the item exists after the rewrite.

Items: heading lines, inline code spans, short **bold** labels (6 words or fewer, starting with a capital), numbers, file names, --flags,
fenced code blocks (exact), table row count, and the manual keywords in
scripts/skill-wording-manifest.tsv (file<TAB>keyword; the keyword must exist in both).
Frontmatter: `name` and `version` must be identical. The description must keep the
trigger words in the manifest rows marked DESC.

Usage: python3 scripts/check-skill-wording.py [BASE_REF]
Exit code 1 when an item is missing."""
import re, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = sys.argv[1] if len(sys.argv) > 1 else "origin/main"

def git_show(path):
    r = subprocess.run(["git", "show", f"{BASE}:{path}"], cwd=ROOT, capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None

def split(text):
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    return (m.group(1), text[m.end():]) if m else ("", text)

def fences(body):
    return re.findall(r"```[^\n]*\n.*?```", body, re.S)

def strip_fences(body):
    return re.sub(r"```[^\n]*\n.*?```", "", body, flags=re.S)

def items(body):
    prose = strip_fences(body)
    out = {}
    out["heading"] = set(l.strip() for l in prose.split("\n") if l.startswith("#"))
    out["code"] = set(re.findall(r"`([^`\n]+)`", prose))
    # Short bold spans (6 words or fewer) are labels and must stay. Longer bold spans are emphasis and can be reworded.
    out["bold"] = set(b.strip().rstrip(".:;,") for b in re.findall(r"\*\*([^*\n]+)\*\*", prose) if len(b.split()) <= 6 and not b[:1].islower())
    out["number"] = set(re.findall(r"(?<![\w.])\d+(?:[.,]\d+)*", re.sub(r"`[^`]*`", "", prose)))
    out["file"] = set(re.findall(r"[\w./<>-]+\.(?:md|mjs|ts|py|json|sh|yaml|yml|txt|csv|html|pdf|png)\b", prose))
    out["flag"] = set(re.findall(r"(?<![\w-])--[a-z][\w-]*", prose))
    return out

def table_rows(body):
    return sum(1 for l in strip_fences(body).split("\n") if l.lstrip().startswith("|"))

manifest = []
mp = ROOT / "scripts/skill-wording-manifest.tsv"
if mp.exists():
    for line in mp.read_text(encoding="utf-8").split("\n"):
        if line and not line.startswith("#"):
            parts = line.split("\t")
            if len(parts) >= 2: manifest.append(parts)

files = sorted(p for p in (ROOT / "skills").rglob("*.md") if "node_modules" not in p.parts)
total = missing = 0
per_skill = {}
def miss(skill, msg):
    global missing
    missing += 1
    per_skill.setdefault(skill, [0, 0])[1] += 1
    print(f"MISSING [{skill}] {msg}")
def count(skill, n=1):
    global total
    total += n
    per_skill.setdefault(skill, [0, 0])[0] += n

for p in files:
    rel = p.relative_to(ROOT).as_posix()
    skill = rel.split("/")[2]
    old = git_show(rel)
    if old is None: continue
    new = p.read_text(encoding="utf-8")
    ofm, obody = split(old); nfm, nbody = split(new)
    if p.name == "SKILL.md":
        for key in ("name", "version"):
            for txt, fm in ((old, ofm),):
                ov = re.search(rf"^\s*{key}:\s*(.*)$", ofm, re.M); nv = re.search(rf"^\s*{key}:\s*(.*)$", nfm, re.M)
                count(skill)
                if not ov or not nv or ov.group(1) != nv.group(1): miss(skill, f"{rel}: frontmatter {key} changed")
    oi, ni = items(obody), items(nbody)
    for kind, vals in oi.items():
        for v in sorted(vals):
            count(skill)
            if v not in ni[kind]: miss(skill, f"{rel}: {kind} {v!r}")
    of, nf = fences(obody), fences(nbody)
    for f in of:
        count(skill)
        if f not in nf: miss(skill, f"{rel}: code block changed: {f[:60]!r}")
    count(skill)
    if table_rows(obody) != table_rows(nbody): miss(skill, f"{rel}: table rows {table_rows(obody)} -> {table_rows(nbody)}")
    for parts in manifest:
        f, kw = parts[0], parts[1]
        if f != rel: continue
        desc = len(parts) > 2 and parts[2] == "DESC"
        count(skill)
        if kw not in (old if not desc else ofm):
            miss(skill, f"{rel}: manifest keyword not in base: {kw!r}")
        elif kw not in (new if not desc else nfm):
            miss(skill, f"{rel}: manifest keyword {kw!r}")

print("\nPER SKILL (items listed, missing):")
for s, (n, m) in sorted(per_skill.items()): print(f"  {s}: {n} items, {m} missing")
print(f"SKILL WORDING CHECK: {total} items listed, {missing} missing")
sys.exit(1 if missing else 0)
