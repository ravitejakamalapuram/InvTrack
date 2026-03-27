1. **Add `Semantics` wrapper to `_TemplateCard` in `lib/features/investment/presentation/widgets/template_selector.dart`**:
   - Wrap the `GestureDetector` in a `Semantics` widget.
   - Set `button: true` to indicate it is an interactive element.
   - Set `selected: isSelected` to communicate its state.
   - Provide a clear `label: template.name` to ensure screen readers announce it properly.
   - Use `excludeSemantics: true` inside the `Semantics` widget to prevent screen readers from redundantly reading the complex internal structure (emoji, name, rate).
2. **Document learning**:
   - Add an entry to `.jules/palette.md` noting that custom horizontal scrolling selectors with custom interactive cards should be wrapped in `Semantics(button: true)` with appropriate selection state and clear labels.
3. **Pre-commit checks**:
   - Ensure the code formatting, analysis, and tests pass.
4. **Submit**:
   - Push the branch with a clear commit message.
