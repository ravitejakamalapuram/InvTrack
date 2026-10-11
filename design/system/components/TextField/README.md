AppTextField: a form input with its label above the box, a 56px filled field with a 14px radius, optional prefix icon or text, a clear button and a primary focus border.

Use it for every text input in a form. In a dialog the bare Material `TextFormField` (global input theme) is used instead; see `Dialog`.

## Anatomy

- Label above: `body-large` (18px) at weight 600 in `text`, at least 44 x 44 so tapping it focuses the field, 8px above the box. It is excluded from the semantics tree because the field carries the same label.
- Box: `surface` fill, 1px `field-border`, `radius-field` 14, padding 16 x 16 (56px tall), text `body` 16 in `text`. Hint `body` in `text-subtle`. Prefix icon 24px in `text-muted`, or prefix text (for example "₹") in `text`. A 20px clear button (cancel icon, `neutral-400-light`, the same hex in dark) appears while the field has text and is editable.
- Focus: a 2px border in the light-mode primary (`#5b4cdb`, both themes). Error: 1px `error` border (2px when focused) and a message below.
- Multi-line: `maxLines` greater than 1; icons align to the top.
- Read-only and disabled fields keep the clear button hidden.

## States

Empty with hint · filled with clear button · focused · error with message · multi-line · read-only.

## Consumer provides

`label`, `hint`, `value`, `prefixIcon` or `prefixText`, `error` (a localised message such as "Enter a value of 0 or more"), `mode` (`inputmode`: use `decimal` for amounts), `multiline`, `readonly`. Parse lakh-grouped input ("12,34,567") but reject a decimal comma.

## Rules

- Always give the field a visible label; the hint is an example, not a label.
- Show the error as text, not only a red border.
- Amount fields name their currency in the label ("Value in INR").
- Keep 20px (`form-field-gap`) between fields.

## Contrast

`field-border` is 1.26:1 on `card` (light) and 1.31:1 on `background` (dark) against the 3:1 asked of a control boundary; the field is told apart by its fill and focus border. The hint (`text-subtle`) is 2.31:1 on `surface` in light and 4.13:1 in dark. The focus border `#5b4cdb` is 5.50:1 on `surface` in light and 3.30:1 on #0a0a0a in dark. The `error` red is 3.45:1 on `surface` in light. Kept as drawn.

## Source

`app_text_field.dart`; the global `inputDecorationTheme` in `app_theme.dart` (fill `input-fill`, 12px radius) applies to inputs that do not use AppTextField.
