# Motion and interaction audit

Read for animation, transition, gesture or interaction-feedback questions within Design. Assess purpose and observed behavior, not whether adding animation would make the product look busier. Use the project's motion tokens and platform requirements; do not invent a universal duration or frame-rate target.

## Observe the full interaction

Record the trigger, starting state, intermediate behavior, final state, device/browser, settings and evidence. Cover relevant interactions:

- **Meaning:** can users understand what changed and whether the action completed? Feedback must reflect actual saved state rather than merely an animation ending.
- **Responsiveness:** when does feedback begin and when can users act again? Distinguish network delay, rendering delay and intentional duration. Check whether decorative transitions block input.
- **Interruption:** repeat, cancel, navigate back or start another transition. Check final state, focus, hit targets and duplicate mutations. Use disposable data for persistent actions.
- **Accessibility:** exercise supported reduced-motion settings and alternative feedback. Confirm meaning remains available without movement and focus is preserved. Assess flashing or vestibular concerns against applicable requirements with evidence, not guessed thresholds.
- **Runtime cost:** use an appropriate trace/profiler for frame timing, dropped frames, long tasks or interaction latency. Record build type, device, conditions and sample scope. Browser measurements do not prove native-device behavior.

## Evidence limits

A screenshot cannot establish duration, smoothness, interruption handling or reduced-motion behavior. Source shows configured timing, not actual frame delivery. Video supports visible behavior but does not substitute for runtime timing instrumentation. With static evidence only, mark dynamic checks unverified and identify the runtime, recording or trace needed.

Compare before/after under matching conditions for authorized fixes. Changed duration in code does not prove improved responsiveness or fewer dropped frames. Absence of animation is not itself a defect; tie recommendations to intended user outcomes.

## Report

For each interaction provide expected behavior, evidence, observed result and verified / issue found / unverified / not applicable status. Link issues to the applicable rule or explain measured user impact. Merge UX, accessibility, performance and correctness evidence into one finding per root cause. Audit authority does not authorize new behavior or external actions.
