# Real hardening verification

## Current local checks (2026-09-13)

Six workflows are retained: Start, Brainstorm, Plan, Audit, Check and Research. Audit progressively loads Product, Module, Design (including Motion), Monetization, Security, Quality and web Performance. Checks below concern the current local source; they do not establish publication or live model behavior.

Run the offline regression suite from the repository root:

```sh
python3 scripts/test-audit-regressions.py
```

| Requirement | Reproducible evidence | Boundary |
|---|---|---|
| Complete audit reference installation | Installer tests remove each of the 12 references and require rejection before existing links change | Disposable checkout and destination only |
| Safe installation and rerun | Complete/repeated install and foreign-directory preservation tests | Does not execute machine-wide bootstrap |
| Exact approved change | Correct label passes; wrong value, extra key, missing source, extra file and workflow tampering fail | Mechanical filesystem checks |
| Read-only scope | Unchanged workspace passes; new or modified files fail | Does not grade response quality |
| Runner acceptance | Mock runner verifies correct edit passes and correct edit plus unauthorized file fails; serialized summaries retain pending semantic review | Mock subprocess, no model invocation |
| Platform-specific design rules | Shared outcomes and separate Web/Native sections in the baseline | Source review; native/browser runtime behavior remains unverified |
| Public URL check (`real-check`) | One-off fixture runs on 2026-10-03 against local servers. Spec fixture (640 px fixed-width block, link to an existing page, link to a missing page, script error): exactly three findings (console, broken link, 375 px overflow) in one-page EN and TR PDFs, existing link not flagged; defect-free page exit 3, unreachable address exit 4, `--control` writes only the tracking row, bad URL exit 2. Rule fixtures: 410/500 links are findings; 403/429/503 links and a failed third-party load are warnings; a logout link is never requested; an aborted POST, the generic "Failed to fetch" error and a closed WebSocket are dropped with a warning, while genuine inline errors on a page that POSTs to itself are kept; no viewport setting gives one `noViewport` finding instead of overflow; a 403 home page with `cf-mitigated` exits 6; a redirect off the site is not followed and not counted as broken, redirects to a logout URL are not followed, and redirect loops are warnings; clipped long URLs, a page-count warning, and a numbered folder for a second run on the same day | Fixtures are not stored in the repository, so this is not an automated test. Rule-based, not a quality score; real sites, real bot protection and natural-language routing to `real-check` are not evaluated |

The suite currently contains 14 test methods, including per-reference and runner subcases. All six skill entrypoints pass the skill metadata validator (rerun 2026-10-03). Installer/bootstrap shell syntax and diff whitespace checks pass. These results apply to the checked local revision; rerun after relevant changes.

## Historical evidence no longer retained

Earlier behavioral evaluation artifacts and comparison directories were removed. Their transcripts, manifests and workspaces are no longer independently inspectable in this repository. Previous routing, approval, injection resistance, semantic review and baseline-comparison claims must not be treated as current verified results. Deleted evidence is not restored or linked here.

## Remaining evidence boundaries

New instruction revisions still need controlled behavioral evaluation with retained artifacts and semantic review. A successful process exit or exact file edit is not a quality score. Presented-catalog selection does not establish native implicit discovery. No general quality improvement over a baseline is established by the current offline checks.

Source review does not establish screen-reader behavior, native target usability or motion quality. Those require relevant running-product evidence. Bootstrap is syntax checked only; machine-wide provisioning is not executed. Publication status must be checked separately from local validation.
