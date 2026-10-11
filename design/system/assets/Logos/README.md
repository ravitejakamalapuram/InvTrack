The InvTrack app mark, "Portfolio ring": a ring made of three segments, with one green slice lifting up and out. The files live in `assets/icons` of the app repository and are the source of truth; this group does not hold copies. Use them as-is; never redraw, recolour, crop or re-export them.

Colours: ground `#1A1A2E` (the adaptive-icon background in `pubspec.yaml`), two violet segments (`#C2B8FF` to `#9B8CFF`, and `#9B8CFF` to `#6C63FF`) and the green slice (`#4ADE80` to `#22C55E`).

Sources, on the 108-unit Android adaptive canvas (the visible area is the centre 72 units):

- `app_icon.svg`: the full icon, ground included.
- `app_icon_foreground.svg`: the ring on a transparent ground, for the adaptive foreground layer.
- `app_icon_monochrome.svg`: the ring in one colour, for the Android 13 themed icon.

Exports:

- `app_icon.png` (1024 x 1024, opaque): the full icon cropped to the 72-unit launcher area, so the ring fills the square. It carries its own navy ground, so it sits on any page background as a square.
- `app_icon_foreground.png` and `app_icon_monochrome.png` (432 x 432, transparent): the source for the launcher layers (`flutter_launcher_icons`, inset 0).
- `app_icon_mark.png` (512 x 512, transparent): the ring cropped to the visible 72 units. The app-lock and privacy screen draws it at 72px: a white mark in light mode (tinted with `BlendMode.srcIn`), the coloured mark in dark mode.
- `play_store_512.png` (512 x 512, 32-bit): the Play Store listing icon. The owner uploads it in Play Console.

The coloured files are multi-colour pictures: show them through `<img>`, which cannot inherit `currentColor`, and never tint them. Only `app_icon_mark.png` is tinted, and only by the app-lock screen.

Not covered: the iOS icons still carry the old mark until iOS resumes (the web, macOS, Windows and Linux folders were removed in #975).

Stale copies: the `app_icon.png` and `app_icon.svg` listed for this group in `design-system.json` are the old mark (a ring broken by an arrow, with a grey sparkle in one corner; replaced in #985). Do not use them; take the files from `assets/icons`. They stay in the manifest until the design project's Logos group is re-uploaded.
