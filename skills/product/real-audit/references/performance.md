# Web performance audit mode

Argument: app or variant name. Resolve it from the request and the current project context. If several targets stay plausible, clarify the target. Do not expand silently to every app.

**When to run**

- A new **dependency** was added. This is the most common source of overruns.
- A heavy screen or chart was added.
- Before going live.
- Someone says "the app got slow".

Use the actual production build and browser evidence.
- Find the build command, output location, route and environment from the project. Do not assume a `dist/assets` layout.
- Run only authorized local build and measurement steps. Record the build revision and date.
- Source inspection gives hypotheses. It does not give measured load or latency results.

## Budget

Check the `DESIGN.md` of the project first. An existing budget applies.
- If there is none, use this baseline provisionally. Record that no agreed budget exists. Name who must set one.
- Do not change DESIGN.md without applicable authorization.

| Measure | Baseline budget |
|---|---|
| Initial-route JS + CSS payload (gzip estimate) | **≤ 220 KB**, provisional until the project defines its scope |
| Single lazy chunk (raw) | **≤ 350 KB** |
| Spread between variants (multi-brand) | **≤ 10%** |
| LCP · INP · CLS | **< 2.5s · < 200ms · < 0.1** (field data separately) |

## Measurement scope and evidence

Keep these quantities separate:

- **Direct document assets**: external JavaScript and CSS that the rendered document references directly. This is a partial inventory. It is not the complete first-load payload.
- **Initial-route JS + CSS payload**: the unique JS/CSS resources that the initial route requires or requests in a stated observation window.
  - It includes transitive imports, preload requests, and dynamic chunks that load during startup.
  - A chunk that you call “lazy” still counts if startup requests it.
- **Total initial-load transfer**: all resource types that transfer in that same window, including the document, images, fonts, and third parties. This is not interchangeable with a JS/CSS-only budget.

Before you compare measurements, define these items:
- the route
- the start and end milestone
- the cache and service-worker state
- the viewport and device
- the throttling
- the compression

Then follow these rules:
- Report exact bytes and units.
- A gzip estimate that you compute locally is not measured network transfer. Distinguish raw file bytes, encoded response payload, and actual transfer size.
- Do not use disk allocation as file length. Do not round each asset before you sum.

1. Inspect the production document and the manifest of the build tool, or its supported dependency analysis.
   - Resolve URLs with the real document or base URL, including relative paths, deployment prefixes, query strings, and external origins.
   - Follow the dependency graph. Do not match a fixed file name pattern.
2. Capture the selected route in an appropriate test browser. Inspect its network trace through the stated milestone.
   - Reconcile the observed JS/CSS requests with the build graph.
   - Account for startup dynamic imports and preload requests.
   - Identify intentional prefetches separately.
   - For server-rendered apps, use the actual rendered responses.
3. Report the direct-document, initial-route JS/CSS, and total-transfer inventories separately. Deduplicate by resolved resource identity.
   - If browser evidence is not available, label graph-only results as static estimates.
   - Do not claim a complete runtime first load.
4. Mark a metric **unverified** in any of these cases:
   - the output format is not supported
   - a required path or external resource cannot be resolved
   - the graph or trace is incomplete
   - required measurement tooling is not available

   An empty match set or a skipped file is never evidence of `0 KB`. Name the missing evidence and the verifier.
5. Classify deferred chunks with the graph and the observed request timing.
   - Count and size only the verified deferred set. Not all `.js` files are lazy chunks.
   - Investigate dependency duplication with module-level build analysis. Do not use package-name text matches in minified files.
6. Measure LCP, INP or interaction latency, and CLS with appropriate browser traces or available field telemetry.
   - Record which metric, method, sample/window, and environment you observed.
   - Do not derive them from bundle size. Do not mix lab and field results.

Report budget overruns explicitly. Compare only metrics with matching scope, units, and conditions. If they do not match, mark the budget comparison unverified and explain what you must measure.

## Where to look on overrun

Use these as hypotheses. Confirm them with the build graph and a browser trace before you propose a fix:

1. **Startup imports unnecessary code.** Trace which import causes code that is not related to the initial route to load. Consider route or feature splitting where the measured request pattern supports it.
2. **A dependency or dictionary dominates the payload.** Attribute bytes with the analysis of the build tool.
   - Evaluate reuse, selective imports, or deferred loading against the actual route needs.
   - An additional library does not by itself prove a budget failure.
3. **Duplicate modules or excessive requests add cost.** Confirm the duplicated module content and the request overhead.
   - Choose a remedy that the current bundler of the project supports.
   - Do not infer duplication from a package-name substring. Do not apply a bundler-specific option blindly.
4. **Resource priority delays visible content.** Inspect the request timing of fonts, images, stylesheets, and third parties.
   - Test selective preload, deferral, or font-loading changes against the target metric.
   - After a change, confirm that the page requests the intended resource with the expected priority.
5. **Interaction or state transitions feel slow.** Measure interaction latency and layout shifts.
   - Consider these options, according to the state patterns of the project:
     - keep existing content during refresh
     - reserve layout space
     - render lists in a bounded way
   - Optimistic updates need a defined failure/recovery contract and applicable implementation authorization. They are not a default remedy for sensitive operations.

### D. Verify

After every fix, **measure again and compare**. "Feels faster" is not evidence.

```
metric/scope: <target metric and observation conditions>
before:       <value and unit>
after:        <value and unit> (delta)
```

Evaluate the metric that the fix targets:
- gzip bytes for bundle reduction
- LCP for first paint
- INP or measured interaction latency for responsiveness
- CLS for layout stability

Record the environment, the baseline and the after measurements. Protect the other budgets.
- An unchanged bundle size does not invalidate a latency or stability improvement.
- If you cannot measure the target metric, mark the result unverified.
- Revert only the authorized change that you evaluate, when evidence shows that it failed or regressed required budgets.

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
On overrun: <resource or operation, measured impact, decision owner>
```

Use the actual project budget, or label the provisional baseline clearly. Omit inapplicable metrics with a reason. Never substitute a partial measurement for the requested result.

## Sibling skills

| Skill | When |
|---|---|
| `real-plan` | Sharpen and gate a change before code |
| `real-audit` Product | Whole-product direction and next release |
| `real-audit` Module | Missing scenarios in a built module |
| `real-audit` Design | Screen or flow quality |
| `real-audit` Performance | Measured web performance (this mode) |
