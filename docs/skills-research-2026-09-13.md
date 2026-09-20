# Skills research

13 September 2026. Scope: comparing the local 0.8.0 working tree against official guides and primary installer sources. This is not a live model evaluation.

## Conclusion

Keep the four workflows; the next investment should be real trigger and behaviour evaluation. There is no measured justification for adding a new command or model family.

## Findings and sources

1. **Triggering and result quality are separate tests.** A trigger test measures whether the model selects the right skill; a result test measures whether the selected skill completes the task correctly. Use real user phrasings, near-miss out-of-scope requests and repeated runs. [Trigger guide](https://agentskills.io/skill-creation/optimizing-descriptions), [result evaluation guide](https://agentskills.io/skill-creation/evaluating-skills).

   Local fact: the four entry files total 90 lines; README examples exist, but the inspected repository holds no versioned behaviour-evaluation set or run outputs. Inference: earlier structural checks do not establish the reliability of automatic selection.

2. **Automatic use is supported, not guaranteed.** Claude may select a suitable skill from its description; `disable-model-invocation: true` turns automatic invocation off. None of the four workflows carry that block. Adding the word "automatically" is not evidence of selection. [Claude Code skills](https://code.claude.com/docs/en/skills).

   Suggestion: phrase README expectations as "may select when applicable", and measure the overlap between Audit and Research across queries in both languages.

3. **Keep the short entry point and conditional reference loading.** The official guide recommends supplying specific procedures rather than repeating general knowledge the model already has, and loading detail on demand. [Authoring guidance](https://agentskills.io/skill-creation/best-practices).

   Inference: the current four-entry structure is a reasonable starting point. Checking run logs for whether a single-screen audit needlessly reads Product or Performance references is more useful than splitting the structure again.

4. **Full-bundle dependency is a real installation limit.** Supporting files are part of a skill package; the standard does not define automatic sibling-skill installation. The Vercel installer installs the selected skill only. Plan's dependency on Audit must therefore stay explicit and be verified under a partial installation. [Specification](https://agentskills.io/specification), [installer source](https://github.com/vercel-labs/skills/blob/main/src/installer.ts).

5. **An npx upgrade does not guarantee removal of old names.** In the source, installing the selected target is not a bulk migration of differently named earlier copies. The local installer checks legacy links; the README's npx path has no equivalent migration step for old copies. The claim that "all four appear" must state the upgrade precondition. [Installer source](https://github.com/vercel-labs/skills/blob/main/src/installer.ts).

## Proposed first experiment

Three behaviour scenarios are enough to start:

- "Audit this screen only": a local report is produced; source and project policy stay unchanged.
- "Apply the change I approved": existing scope authorization is not requested again.
- An inaccessible screen: the result is unverified/incomplete, never ship-ready.

Run each scenario in a clean context against the current version and either the previous version or a no-skill baseline. Record outputs, tool history, changed files, duration and token count. Evaluate mechanical checks programmatically; for qualitative comparison, hide version names where possible. This is the comparative evaluation setup the source guide recommends. [Evaluation method](https://agentskills.io/skill-creation/evaluating-skills).

Build a separate trigger set with positive, ambiguous and negative examples such as "what is missing in the product", "research competitor pricing" and "just fix this sentence". Fix the target model, client, session and other installed skills. There is no measurement yet for success rate or token savings; no numeric targets were invented in this report.

## Limits

Live triggering, output quality and cost comparison on Claude or Codex were not run in this research. Open-source links point at main branches and may change over time. Only a research report was produced; no skill or installation behaviour was changed in this round.
