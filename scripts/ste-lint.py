#!/usr/bin/env python3
"""Simple ASD-STE100 style lint for Markdown. Usage: ste-lint.py [--strict] FILE...
Flags sentences over 25 words (error) or 20 words (warning), and banned words.
Also prints NOTE lines for advisory patterns (semicolon, phrasal verb, marketing adjective,
nominalization, passive voice, present perfect). NOTE lines do not change the exit code.
Ignores code blocks, inline code, links, tables, HTML tags and front matter.
Exit code 1 when an error or a banned word is found."""
import re, sys
BANNED = r"\b(should|may|might|ensure|make sure|utili[sz]e|e\.g\.|i\.e\.|etc\.?|via|prior to|in order to|bot|bots)\b"
# Advisory patterns from danyuchn/asd-ste100-skill scripts/ste-lint.py (MIT, Copyright (c) 2026 Dustin Yuchen Teng).
# Synonym rotation is not ported: docs/ste-glossary.md fixes the terms, and its groups differ (verify vs confirm).
_PP = "given|taken|made|done|found|seen|known|shown|written|built|sent|set|run|read|kept|held|left|put"
_IRR = _PP + "|cut|hit|let|shut|split|spread|begun|become|come|gone|got|gotten|lost|met|paid|said|sold|told|thought|brought|bought|caught|taught|won|worn|torn|born|drawn|grown|thrown|flown|driven|risen|chosen|broken|spoken|frozen|hidden|ridden|forgotten|fallen|eaten|beaten|understood|stood|struck|stuck|swung|hung|led|fed|bled|fled|sped|bound|wound|dug|spun|slid|bit|lit|quit"
ADVISORY = [
    ("semicolon", re.compile(r";"), "split into two sentences"),
    ("phrasal-verb", re.compile(r"\b(spin(?:ning|s)? up|spun up|reach(?:ing|es|ed)? out|div(?:e|es|ing|ed) into|dove into|kick(?:ing|s|ed)? off|circl(?:e|es|ing|ed) back|touch(?:ing|es|ed)? base|hand(?:s|ed|ing)? off)\b", re.I), "use one plain verb"),
    ("marketing-adjective", re.compile(r"\b(seamless(?:ly)?|robust(?:ly)?|cutting-edge|effortless(?:ly)?|blazing[- ]fast|world-class|state-of-the-art|game-chang(?:ing|er))\b", re.I), "delete it or give the measurement"),
    ("nominalization", re.compile(r"\b(perform|performs|performed|conduct|conducts|conducted|carry out|carries out|carried out)\s+(?:a|an|the)\s+\w+(?:tion|sion|ment|ance|ence|ysis)\b", re.I), "use the verb"),
    ("passive-voice", re.compile(r"\b(is|are|was|were|been|being)\s+(\w+ed|" + _PP + r")\b(?!\s+(?:to|for|by)\s+\w+ing)", re.I), "name the actor, use the active voice"),
    ("present-perfect", re.compile(r"(?<!\bmay )(?<!\bmight )(?<!\bcould )(?<!\bshould )(?<!\bwould )(?<!\bmust )\b(has|have|had)\s+(?:been\s+)?(?:\w+(?:ed|en)|" + _IRR + r")\b", re.I), "use the simple past or present"),
]
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
        t = re.sub(r"\*\*[^*]*\*\*", "X", t)  # bold labels are fixed names
        t = re.sub(r"[*_#>]", "", t).strip()
        if not t: continue
        for s in re.split(r"(?<=[.!?])\s+", t):
            s = s.strip()
            if s: out.append((n, s))
    return out
def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    errors = warns = banned = notes = 0
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
            for rule, rx, fix in ADVISORY:
                m = rx.search(s)
                if m:
                    notes += 1; print(f"NOTE  {f}:{n}: {rule} '{m.group(0)}', {fix}: {s[:70]}")
    print(f"STE LINT: {errors} errors (over 25 words), {warns} warnings (21-25 words), {banned} banned words, {notes} notes")
    sys.exit(1 if errors or banned else 0)
main()
