AppTextField: a form input with its label above the box, a 56px filled field with a 14px radius, optional prefix icon or text, a clear button and a primary focus border.

Use it for every text input in a form. In a dialog the bare Material `TextFormField` (global input theme) is used instead; see `Dialog`.

## Anatomy

- Label above: `body-large` (18px) at weight 600 in `text`, at least 44 x 44 so tapping it focuses the field, 8px above the box. It is excluded from the semantics tree because the field carries the same label.
- Box: `surface` fill, 1px `field-border`, `radius-field` 14, padding 16 x 16 (56px tall), text `body` 16 in `text`. Hint `body` in `text-subtle`. Prefix icon 24px in `text-muted`, or prefix text (for example "₹") in `text`. A 20px clear button (cancel icon, `neutral-400-light`; `neutral-400-dark` in dark) appears while the field has text and is editable.
- Focus: a 2px border in `primary` (`#5b4cdb` in light, `#8b7cf6` in dark). Error: 1px `error` border (2px when focused; `#cc1926` in light, `#f87171` in dark) and a message below.
- Multi-line: `maxLines` greater than 1; icons align to the top.
- Read-only and disabled fields keep the clear button hidden.
- Hint while empty (`showHintWhenEmpty`, off by default): normally the label also sits inside an empty, unfocused field, which hides the hint and a text prefix until the field is focused. With it on, the field shows its hint and prefix as they are in the HTML mock (a rupee sign and "e.g. 1,00,000"), and only the label above the box remains; a screen reader still hears the label, then the hint. Used by the add-investment fields behind the first investment flow (name, amount, rate).
- Helper line (`FormHelperText`, `InvTrack.TextField({ helper })`): 12px `small` in `text-muted`, 6px under the box and 16px in from its edge, outside the field so it stays when an error shows. It carries a note that a field is optional ("Optional. You can add it later."), the readout of an amount ("₹1.5 L", weight 600 in `text-secondary` with `helperStrong`) and the line under the start date ("Today. Also the date of your first cash flow."). In privacy mode the readout reads "Hidden amount", visually and to a screen reader; the screen reader otherwise hears the amount in full ("1.5 lakh rupees").

## States

Empty with hint · filled with clear button · focused · error with message · multi-line · read-only.

## Consumer provides

`label`, `hint`, `value`, `prefixIcon` or `prefixText`, `error` (a localised message such as "Enter a value of 0 or more"), `helper`, `mode` (`inputmode`: use `decimal` for amounts), `multiline`, `readonly`. Parse grouped input ("12,34,567"). A comma before one or two digits is the decimal mark ("1,50" is 1.50, which the readout under the field shows), and separators that fit no reading ("1,5000") or two ("1.500" in en_US) are an error, never a guess (`parseAmountInput`).

## Rules

- Always give the field a visible label; the hint is an example, not a label.
- Show the error as text, not only a red border.
- Amount fields name their currency in the label ("Value in INR", "Amount invested in EUR") and show that currency's symbol as the prefix, never another's.
- An optional amount stays optional: say so under the empty field and never default it. A start date that defaults to today says what it is for.
- A read-only field that opens a picker (the start date) is still on the keyboard's path: Tab reaches it, it shows the focus border, and Enter or Space opens the picker.
- Keep 20px (`form-field-gap`) between fields.

## Contrast

`field-border` is 1.26:1 on `card` (light) and 1.31:1 on `background` (dark) against the 3:1 asked of a control boundary; the field is told apart by its fill and focus border. The hint (`text-subtle`) is 4.60:1 on `surface` in light and 5.23:1 on #0a0a0a in dark. The focus border is `#5b4cdb`, 5.50:1 on `surface`, in light and `#8b7cf6`, 5.95:1 on #0a0a0a, in dark. The `error` red is `#cc1926` in light, 5.15:1 on `surface`.

## Source

`app_text_field.dart`; the global `inputDecorationTheme` in `app_theme.dart` (fill `input-fill`, 12px radius) applies to inputs that do not use AppTextField.
