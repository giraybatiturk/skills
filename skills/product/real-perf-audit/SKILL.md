---
name: real-perf-audit
description: Measures bundle and load performance against a budget, finds where an overrun comes from, and applies the fix recipes. Runs when a dependency is added and before release.
disable-model-invocation: true
---

# /real-perf-audit

Argument: app or variant name. If missing, measure every app in the project.

**When to run**

- A new **dependency** was added; the most common source of overruns
- A heavy screen or chart was added
- Before going live
- Someone says "the app got slow"

Measurement is done on the build output (`dist`); build first. Reading the source and saying "preload is missing" turns out wrong; **measure the build output**.

## Budget

Check the project's `DESIGN.md` first; if a performance budget is written there, it applies. If not, use this baseline, then after the first measurement write real values plus a reasonable margin into `DESIGN.md`:

| Measure | Baseline budget |
|---|---|
| First load (gzip) | **≤ 220 KB** |
| Single lazy chunk (raw) | **≤ 350 KB** |
| Spread between variants (multi-brand) | **≤ 10%** |
| LCP · INP · CLS | **< 2.5s · < 200ms · < 0.1** (field data separately) |

"First load" = the js + css that `index.html` pulls directly. Lazy chunks don't count; they arrive on route entry.

If the budget is exceeded, **stop and report**. Accepting an overrun silently makes a bigger overrun normal next round.

## Measurements (copy and run)

Replace `<dist>` with the app's build directory.

```bash
# 1. First load, gzip
d=<dist>; raw=0; gz=0
for f in $(grep -oE '/assets/[A-Za-z0-9_.-]+\.(js|css)' "$d/index.html" | sort -u); do
  p="$d$f"; [ -f "$p" ] || continue
  raw=$((raw + $(du -k "$p" | cut -f1)))
  gz=$((gz + $(gzip -c "$p" | wc -c) / 1024))
done
printf "%5s KB raw -> %4s KB gzip\n" "$raw" "$gz"

# 2. First-load breakdown: which file, how much
for f in $(grep -oE '/assets/[A-Za-z0-9_.-]+\.(js|css)' "$d/index.html" | sort -u); do
  p="$d$f"; [ -f "$p" ] || continue
  printf "%5s KB gz  %s\n" "$(( $(gzip -c "$p" | wc -c) / 1024 ))" "$(basename $f)"
done | sort -rn

# 3. Largest lazy chunks
find <dist>/assets -name "*.js" -exec du -k {} + | sort -rn | head -10

# 4. Lazy chunk count: is code splitting working
find <dist>/assets -name "*.js" | wc -l

# 5. How many chunks a dependency lands in
grep -c "<package-name>" <dist>/assets/*.js 2>/dev/null | grep -v ":0" | head

# 6. Is preload actually emitted
grep -oE '<link rel="(preload|modulepreload)"[^>]*>' <dist>/index.html
```

## Where to look on overrun

Order matters; the top ones pay the most.

1. **Lazy content leaked into first load.** If a route component landed in the entry chunk, code splitting broke. If `index-*.js` grew suddenly, look here: `grep -oE "[A-Z][a-zA-Z]+(Screen|Page)" <dist>/assets/index-*.js | sort -u`
2. **New dependency.** Is there already something that does the same job (the ladder: stdlib → native platform → installed dependency → new package)? A second date/icon/table library breaks both the budget and consistency.
3. **Dictionary files.** A large i18n dictionary should be split `core`/`rest`; only `core` in first load.
4. **Chart and table libraries.** Must stay route-lazy; if one leaks into a non-dashboard screen, it shows.
5. **Duplicated vendor.** The same library in two chunks means `manualChunks` needs a look. Precedent: the `react-dom/client` subpath wasn't caught by the `'react-dom'` entry and 498 KB of client runtime stayed in the entry chunk; a separate entry for the subpath fixed it.

## Fix recipes

### A. First load too big

- **A1. A route leaked into the entry.** Not split with `React.lazy`, or a parent imports it directly. Most common and biggest win.
- **A2. Dictionary in the entry.** `grep -c "rest" <dist>/index.html` must be zero.
- **A3. New dependency.** The ladder, before adding.
- **A4. Too many tiny chunks.** 1 KB chunks as separate files make the cost **request count**, not size (one route transition opened 14 requests). Merge with `experimentalMinChunkSize`. Check the chunk count whenever a route is added.

### B. First paint (LCP) slow

- **B1. Preload, but selectively.** Only the font and dictionary slice needed for the first frame. Precedent: two mono font files (44 KB) downloaded at top priority and pushed the dictionary chunk the render was waiting for to the end of the wave; preloading the `rest` dictionary raised login FCP from 640 to 1224 ms. If the preload pattern is tied to a file name, it **fails silently** when the name changes; verify with measurement 6 after every change.
- **B2. `font-display: swap`.** FOIT shifts LCP.
- **B3. Defer non-critical third parties.** Analytics, chat widgets, map SDKs don't hold the first paint; load only for the user who needs them, only once.

### C. Perceived performance

Measured time is fine but it **feels** slow:

- **C1. Skeleton, not spinner.** A skeleton that mimics the coming layout cuts CLS. Canonical mapping in the project's DESIGN.md.
- **C2. Don't swap content on background refresh.** During `isFetching`, keep the content; use a thin progress line.
- **C3. Optimistic UI.** The cheapest way to hold the 400 ms Doherty threshold. **Not** for operations that write money or records.
- **C4. Long lists.** Pagination is right for most screens; virtualise only lists that can't paginate (boards, chat streams).

### D. Verify

After every fix, **measure again and compare**. "Feels faster" is not evidence.

```
before:  <n> KB gzip
after:   <n> KB gzip   (delta, %)
```

If the bundle didn't shrink, the change didn't work; revert and try the next recipe.

## Output

```
App         First load (gzip)   Budget   Status
<name>      <n> KB              220 KB   ✓ / ✗

Largest lazy chunk:  <name> <size> (budget 350 KB)
Lazy chunk count:    <n>
Build date:          <date>

On overrun: which file, how much, likely cause, proposed step.
```

Measurement is on `dist`, so **write the build date**; measuring a stale `dist` misleads.

## Sibling skills

| Skill | When |
|---|---|
| `/real-feature-gate` | Before writing code |
| `/real-module-audit` | Missing scenarios in a built module |
| `/real-design-audit` | Screen is done; visual + DESIGN.md check |
| `/real-perf-audit` | Dependency added, before release (this skill) |
| `/real-start` | When you don't know which one |
