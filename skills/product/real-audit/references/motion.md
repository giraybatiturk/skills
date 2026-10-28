# Motion and interaction audit

Read this for questions about animation, transition, gesture or interaction feedback within Design.
- Assess the purpose and the observed behavior. Do not assess whether more animation would make the product look busier.
- Use the motion tokens and platform requirements of the project. Do not invent a universal duration or frame-rate target.

## Observe the full interaction

Record the trigger, starting state, intermediate behavior, final state, device/browser, settings and evidence. Cover the relevant interactions:

- **Meaning:** can users understand what changed and whether the action completed? Feedback must show the actual saved state. It must not show only that an animation ended.
- **Responsiveness:** when does feedback begin, and when can users act again? Distinguish network delay, rendering delay and intentional duration. Check whether decorative transitions block input.
- **Interruption:** repeat, cancel, navigate back or start another transition. Check the final state, focus, hit targets and duplicate mutations. Use disposable data for persistent actions.
- **Accessibility:** exercise the supported reduced-motion settings and the alternative feedback. Verify that the meaning stays available without movement and that focus is preserved. Assess flashing or vestibular concerns against the applicable requirements with evidence. Do not use guessed thresholds.
- **Runtime cost:** use an appropriate trace or profiler for frame timing, dropped frames, long tasks or interaction latency. Record the build type, device, conditions and sample scope. Browser measurements do not prove native-device behavior.

## Evidence limits

A screenshot cannot establish duration, smoothness, interruption handling or reduced-motion behavior.
- Source shows configured timing, not actual frame delivery.
- Video supports visible behavior. It does not replace runtime timing instrumentation.
- With static evidence only, mark dynamic tests unverified. Identify the runtime, recording or trace that you need.

For authorized fixes, compare before and after under matching conditions.
- A changed duration in code does not prove better responsiveness or fewer dropped frames.
- The absence of animation is not a defect in itself. Tie recommendations to the intended user outcomes.

## Report

For each interaction, give the expected behavior, the evidence, the observed result and a status: verified / issue found / unverified / not applicable.
- Link issues to the applicable rule, or explain the measured user impact.
- Merge UX, accessibility, performance and correctness evidence into one finding for each root cause.
- Audit authority does not authorize new behavior or external actions.
