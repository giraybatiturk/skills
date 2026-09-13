# Web performance audit mode

Argument: app or variant name. Resolve it from the request and current project context. If several targets remain plausible, clarify the target; do not silently expand to every app.

**When to run**

- A new **dependency** was added; the most common source of overruns
- A heavy screen or chart was added
- Before going live
- Someone says "the app got slow"

Use the actual production build and browser evidence. Identify the build command, output location, route, and environment from the project; do not assume a `dist/assets` layout. Run only authorized local build and measurement steps, and record build revision/date. Source inspection supplies hypotheses, not measured load or latency results.

## Budget

Check the project's `DESIGN.md` first; an existing budget applies. Otherwise use this baseline provisionally and propose a measured budget in the report. Do not modify DESIGN.md without applicable authorization:

| Measure | Baseline budget |
|---|---|
| Initial-route JS + CSS payload (gzip estimate) | **≤ 220 KB**, provisional until the project defines its scope |
| Single lazy chunk (raw) | **≤ 350 KB** |
| Spread between variants (multi-brand) | **≤ 10%** |
| LCP · INP · CLS | **< 2.5s · < 200ms · < 0.1** (field data separately) |

## Measurement scope and evidence

Keep these quantities separate:

- **Direct document assets**: external JavaScript and CSS directly referenced by the rendered document. This is a partial inventory, not the complete first-load payload.
- **Initial-route JS + CSS payload**: the unique JS/CSS resources required or requested through a stated initial-route observation window, including transitive imports, preload requests, and dynamic chunks loaded during startup. A chunk called “lazy” still counts if startup requests it.
- **Total initial-load transfer**: all resource types transferred during that same window, including the document, images, fonts, and third parties. This is not interchangeable with a JS/CSS-only budget.

Define the route, start/end milestone, cache/service-worker state, viewport/device, throttling, and compression before comparing measurements. Report exact bytes and units. A locally computed gzip estimate is not measured network transfer; distinguish raw file bytes, encoded response payload, and actual transfer size. Do not use disk allocation as file length, or round each asset before summing.

1. Inspect the production document and the build tool's manifest or supported dependency analysis. Resolve URLs using the real document/base URL, including relative paths, deployment prefixes, query strings, and external origins. Follow the dependency graph rather than matching a fixed filename pattern.
2. Capture the selected route in an appropriate test browser and inspect its network trace through the stated milestone. Reconcile observed JS/CSS requests with the build graph and account for startup dynamic imports and preload requests. Keep intentional prefetches identified separately. Use actual rendered responses for server-rendered apps.
3. Report direct-document, initial-route JS/CSS, and total-transfer inventories separately. Deduplicate by resolved resource identity. If browser evidence is unavailable, label graph-only results as static estimates; do not claim complete runtime first load.
4. Mark a metric **unverified** if the output format is unsupported, a required path or external resource cannot be resolved, the graph/trace is incomplete, or required measurement tooling is unavailable. An empty match set or skipped file is never evidence of `0 KB`. Name the missing evidence and verifier.
5. Classify deferred chunks using the graph and observed request timing. Count and size only the verified deferred set; all `.js` files are not automatically lazy chunks. Investigate dependency duplication with module-level build analysis, not package-name text matches in minified files.
6. Measure LCP, INP or interaction latency, and CLS using appropriate browser traces or available field telemetry. Record which metric, method, sample/window, and environment were observed; do not derive them from bundle size or conflate lab and field results.

Report budget overruns explicitly. Compare only metrics with matching scope, units, and conditions; otherwise mark the budget comparison unverified and explain what must be measured.

## Where to look on overrun

Use these as hypotheses, then confirm them with the build graph and browser trace before proposing a fix:

1. **Startup imports unnecessary code.** Trace which import causes code unrelated to the initial route to load. Consider route or feature splitting where the measured request pattern supports it.
2. **A dependency or dictionary dominates the payload.** Attribute bytes with the build tool's analysis. Evaluate reuse, selective imports, or deferred loading against actual route needs; an additional library does not by itself prove a budget failure.
3. **Duplicate modules or excessive requests add cost.** Confirm duplicated module content and request overhead. Choose a remedy supported by the project's current bundler; do not infer duplication from a package-name substring or apply a bundler-specific option blindly.
4. **Resource priority delays visible content.** Inspect font, image, stylesheet, and third-party request timing. Test selective preload, deferral, or font-loading changes against the target metric. Confirm the intended resource is actually requested with the expected priority after a change.
5. **Interaction or state transitions feel slow.** Measure interaction latency and layout shifts. Consider retaining existing content during refresh, reserving layout space, and bounded list rendering according to the project's state patterns. Optimistic updates require a defined failure/recovery contract and applicable implementation authorization; they are not a default remedy for sensitive operations.

### D. Verify

After every fix, **measure again and compare**. "Feels faster" is not evidence.

```
metric/scope: <target metric and observation conditions>
before:       <value and unit>
after:        <value and unit> (delta)
```

Evaluate the metric the fix targets: gzip bytes for bundle reduction, LCP for first paint, INP or measured interaction latency for responsiveness, and CLS for layout stability. Record environment, baseline, and after measurements; protect other budgets. An unchanged bundle size does not invalidate a latency or stability improvement. If the target metric cannot be measured, mark the result unverified. Revert only the authorized change being evaluated when evidence shows it failed or regressed required budgets.

## Output

```text
Target: <app/variant, route, build revision/date>
Environment/window: <device, network, cache, start/end milestone>
Metric and scope                 Value/unit   Evidence   Budget   Status
Direct-document JS + CSS         ...          ...        ...      verified/unverified
Initial-route JS + CSS           ...          ...        ...      verified/unverified
Total initial-load transfer      ...          ...        ...      verified/unverified
Target latency/stability metric  ...          ...        ...      verified/unverified

Deferred chunks: <verified set, count, largest raw file bytes>
Budget comparison: <pass/overrun/unverified, with matching scope and units>
Limits: <missing evidence and verifier>
On overrun: <resource or operation, measured impact, proposed next step>
```

Use the actual project budget, or clearly label the provisional baseline. Omit inapplicable metrics with a reason; never substitute a partial measurement for the requested result.

## Sibling skills

| Skill | When |
|---|---|
| `real-plan` | Sharpen and gate a change before code |
| `real-audit` Product | Whole-product direction and next release |
| `real-audit` Module | Missing scenarios in a built module |
| `real-audit` Design | Screen or flow quality |
| `real-audit` Performance | Measured web performance (this mode) |
