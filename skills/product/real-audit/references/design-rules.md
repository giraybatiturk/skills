# Design rules (baseline)

Apply the shared outcomes below to UI work. Then select the relevant platform section.
- The `DESIGN.md` of the project and its established component system take precedence over this fallback.
- A missing `DESIGN.md` does not mean that there is no design direction. Inspect the existing screens, tokens and components.
- This reference does not authorize editing design policy.

## 1. Shared outcomes across platforms

- Give each screen one clear main job. Use size, weight, contrast and space to set the hierarchy. Group related information by proximity.
- Reuse the components of the project and their existing variants before you add new ones. Follow its semantic colour, typography, spacing and shape tokens in the representation that it already uses.
- If a component is missing, search the existing source and consider composition. Explain a necessary addition. Implement it within the scope that is already authorized. Ask only if it changes the scope or the design policy.
- Use the type and spacing scales of the project. Adapt to text enlargement, localization and available space. Do not prescribe CSS pixels, utility classes or a fixed type scale to every platform.
- Check readable contrast in the supported themes. Show meaningful information with more than colour alone. Use the applicable accessibility standard and platform guidance for measured criteria. Record the standard and the measurement. Do not invent a universal touch-target threshold.
- Controls need understandable names, roles, values and states. Do not let decorative imagery add screen-reader noise. Keep a usable focus order and focus indication for the supported input methods.
- Targets must be usable with the input methods and accessibility settings of the platform. Verify the actual hit areas, not only the visible icon size.

## 2. Forms, copy and feedback

- Give fields persistent visible labels. Placeholders can show examples. They must not carry essential instructions.
- Keep help near the field. Associate it programmatically where the platform supports it. State the requirements before users meet preventable errors.
- Validate when the information is actionable. Do not interrupt incomplete input without need.
- Keep the values that users entered. Explain how to recover. Make errors discoverable with assistive technology.
- Use specific, non-blaming error text. Use more than colour to show failure.
- Bind error, invalid, disabled and loading states through the supported API of the component.
- Name actions with clear verbs. Prevent accidental duplicate submissions. Keep progress and recovery understandable.
- Provide appropriate empty, loading, success and failure states. Choose skeletons, progress indicators or inline feedback by the interaction and the known wait. No single loading pattern is mandatory everywhere.
- Keep persistent or important information available beyond a transient message. Provide retry only where retry is meaningful and safe.
- Follow the icon family and sizing conventions of the project. Icon-only controls need accessible names. Unfamiliar meanings also need a visible explanation.
- Write concise copy in the language of the user. Prefer clear, complete instructions over a fixed word-count rule. Use commas, full stops or parentheses instead of em dashes.

## 3. Web implementation only

- Follow the existing CSS, component and layout architecture. Utility classes are an option only when the project uses them. They are not a requirement.
- Prefer semantic HTML and native control behavior. Associate labels with inputs. Associate help and error text with controls through the appropriate HTML or ARIA mechanisms, such as `aria-describedby` and `aria-invalid` when applicable.
- Keep keyboard navigation and visible focus. Use the focus styling of the project, including `:focus-visible` where appropriate.
- Hide decorative icons from accessibility APIs. Give icon-only buttons an accessible name. Do not add redundant ARIA to native semantics that are already correct.
- Verify responsive layout, zoom, text reflow and browser accessibility behavior with the applicable web criteria. CSS units and DOM attributes belong to this section, not to the native rules.

## 4. Native implementation only

- Use the layout, reusable controls, styles and asset/token representations of the native framework. Do not require HTML, CSS utility classes, DOM state attributes or ARIA properties in native views.
- Expose names, roles/traits, values, hints and changing state through the accessibility APIs of the platform. Associate labels and errors through supported native mechanisms. Verify their announcement.
- Support the text scaling and the supported assistive and input methods of the platform. In the running app, verify the screen-reader order, focus behavior, touch targets and interruptions.
- Evaluate target dimensions in the units of the platform against the applicable platform guidance. Do not translate a generic CSS pixel threshold into a native requirement.
- Use the supported appearance modes and the native progress and error patterns of the project. Verify behavior on the intended device or simulator. A browser rendering or source inspection is not native runtime evidence.

## 5. Verification and boundaries

Design and UI audits use `real-audit` Design mode, including Motion when relevant. Record the platform and the supported states before you select tests. For hybrid products, apply each implementation section only to its actual surface.

Before you report completion, verify the relevant components, tokens, interaction states and accessibility outcomes.
- Separate source inspection, screenshots and runtime measurements.
- Report unavailable tests as unverified.
- Screenshots alone do not establish focus behavior, announcements or motion quality.

This baseline does not choose a brand palette or aesthetic. It does not require a theme that the product does not support. Follow the design direction of the project. Name explicitly any conflict with an applicable accessibility requirement.
