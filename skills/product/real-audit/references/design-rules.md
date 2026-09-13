# Design rules (baseline)

Apply the shared outcomes below to UI work, then select the relevant platform section. The project's `DESIGN.md` and established component system take precedence over this fallback. A missing `DESIGN.md` does not mean there is no design direction: inspect existing screens, tokens and components. This reference does not authorize editing design policy.

## 1. Shared outcomes across platforms

- One clear main job per screen. Use size, weight, contrast and space to establish hierarchy; group related information by proximity.
- Reuse the project's components and their existing variants before introducing new ones. Follow its semantic colour, typography, spacing and shape tokens in the representation it already uses.
- If a component is missing, search the existing source and consider composition. Explain a necessary addition and implement it within already authorized scope; ask only if it changes scope or design policy.
- Use the project's type and spacing scales. Adapt to text enlargement, localization and available space. Do not prescribe CSS pixels, utility classes or a fixed type scale to every platform.
- Check readable contrast in supported themes and meaningful information without colour alone. Use the applicable accessibility standard and platform guidance for measured criteria; record the standard and measurement. Do not invent a universal touch-target threshold.
- Controls need understandable names, roles, values and states. Decorative imagery should not add screen-reader noise. Preserve usable focus order and focus indication for supported input methods.
- Targets must be usable with the platform's input methods and accessibility settings. Verify actual hit areas, not only visible icon size.

## 2. Forms, copy and feedback

- Give fields persistent visible labels; placeholders may show examples but must not carry essential instructions.
- Keep help near the field and programmatically associated where the platform supports it. State requirements before users encounter preventable errors.
- Validate when the information is actionable, without interrupting incomplete input unnecessarily. Preserve entered values, explain how to recover, and make errors discoverable with assistive technology.
- Use specific, non-blaming error text and more than colour to communicate failure. Bind error, invalid, disabled and loading states through the component's supported API.
- Name actions with clear verbs. Prevent accidental duplicate submissions while keeping progress and recovery understandable.
- Provide appropriate empty, loading, success and failure states. Choose skeletons, progress indicators or inline feedback according to the interaction and known wait; no single loading pattern is mandatory everywhere.
- Keep persistent or important information available beyond a transient message. Provide retry only where retry is meaningful and safe.
- Follow the project's icon family and sizing conventions. Icon-only controls need accessible names; unfamiliar meanings also need visible explanation.
- Write concise copy in the user's language. Prefer clear, complete instructions over a fixed word-count rule. Use commas, full stops or parentheses instead of em dashes.

## 3. Web implementation only

- Follow the existing CSS, component and layout architecture. Utility classes are an option only when the project uses them; they are not a requirement.
- Prefer semantic HTML and native control behavior. Associate labels with inputs, and help/error text with controls through the appropriate HTML or ARIA mechanisms, such as `aria-describedby` and `aria-invalid` when applicable.
- Preserve keyboard navigation and visible focus. Use the project's focus styling, including `:focus-visible` where appropriate.
- Hide decorative icons from accessibility APIs; give icon-only buttons an accessible name. Do not add redundant ARIA to already correct native semantics.
- Verify responsive layout, zoom, text reflow and browser accessibility behavior with the applicable web criteria. CSS units and DOM attributes belong to this section, not the native rules.

## 4. Native implementation only

- Use the native framework's layout, reusable controls, styles and asset/token representations. Do not require HTML, CSS utility classes, DOM state attributes or ARIA properties in native views.
- Expose names, roles/traits, values, hints and changing state through the platform's accessibility APIs. Associate labels and errors through supported native mechanisms and verify their announcement.
- Support the platform's text scaling and supported assistive/input methods. Check screen-reader order, focus behavior, touch targets and interruptions in the running app.
- Evaluate target dimensions in the platform's units against applicable platform guidance; do not translate a generic CSS pixel threshold into a native requirement.
- Use the project's supported appearance modes and native progress/error patterns. Verify behavior on the intended device or simulator; a browser rendering or source inspection is not native runtime evidence.

## 5. Verification and boundaries

Design/UI audits use `real-audit` Design mode, including Motion when relevant. Record the platform and supported states before selecting checks. For hybrid products, apply each implementation section only to its actual surface.

Before reporting completion, verify the relevant components, tokens, interaction states and accessibility outcomes. Separate source inspection, screenshots and runtime measurements. Report unavailable checks as unverified; screenshots alone do not establish focus behavior, announcements or motion quality.

This baseline does not choose a brand palette or aesthetic and does not require a theme the product does not support. Follow the project's design direction and identify any conflict with an applicable accessibility requirement explicitly.
