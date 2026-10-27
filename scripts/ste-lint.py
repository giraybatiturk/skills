#!/usr/bin/env python3
"""Simple ASD-STE100 style lint for Markdown. Usage: ste-lint.py [--strict] FILE...
Flags sentences over 25 words (error) or 20 words (warning), and banned words.
Ignores code blocks, inline code, links, tables, HTML tags and front matter.
Exit code 1 when an error is found."""
import re, sys
BANNED = r"\b(should|may|might|ensure|make sure|utili[sz]e|e\.g\.|i\.e\.|etc\.?|via|prior to|in order to|confirm(?:s|ed)?|bot|bots)\b"
def sentences(text):
    out = []
    fence = False
    in_front = False
    for n, line in enumerate(text.split("\n"), 1):
        if n == 1 and line.strip() == "---":
            in_front = True; continue
        if in_front:
            if line.strip() == "---": in_front = False
            continue
        if line.strip().startswith("```"):
            fence = not fence; continue
        if fence or line.lstrip().startswith("|"): continue
        t = re.sub(r"<!--|-->", " ", line)
        t = re.sub(r"`[^`]*`", "X", t)
        t = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", t)
        t = re.sub(r"<[^>]+>", " ", t)
        t = re.sub(r"^\s*([-*]|\d+\.)\s+", "", t)
        t = re.sub(r"[*_#>]", "", t).strip()
        if not t: continue
        for s in re.split(r"(?<=[.!?])\s+", t):
            s = s.strip()
            if s: out.append((n, s))
    return out
def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    errors = warns = banned = 0
    for f in args:
        for n, s in sentences(open(f, encoding="utf-8").read()):
            w = len(s.split())
            if w > 25:
                errors += 1; print(f"ERROR {f}:{n}: {w} words: {s[:90]}")
            elif w > 20:
                warns += 1
                if "--strict" in sys.argv: print(f"WARN  {f}:{n}: {w} words: {s[:90]}")
            m = re.search(BANNED, s, re.I)
            if m:
                banned += 1; print(f"WORD  {f}:{n}: '{m.group(0)}' in: {s[:80]}")
    print(f"STE LINT: {errors} errors (over 25 words), {warns} warnings (21-25 words), {banned} banned words")
    sys.exit(1 if errors or banned else 0)
main()
