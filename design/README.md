# InvTrack design system

`design/system/` is a copy of the InvTrack design system: the colour, type, spacing and radius tokens, the shared components with their guidelines, and the product rules that decide what each screen must show. Read `system/README.md` first.

It is **derived from the Dart code**, not the other way round. `lib/core/theme/*` and `lib/core/widgets/*` are the source of truth; when they change, update this copy to match.

## Where it lives

- This folder is the durable copy. Anyone with the repository can read it.
- The browsable version, with live previews, is a Claude artifact: <https://claude.ai/artifact/2VfqfiM44Xf4mAs2nU931b>. It is private to the owner's claude.ai account unless the owner shares it from the page's Share menu, so do not rely on it as the only copy.

The files map one to one: `project/<path>` in the artifact is `design/system/<path>` here.

## What is not copied

- Fonts: `system/tokens.json` lists Inter at 400, 500 and 600 as `fonts/Inter-*.ttf`. The real files are in `assets/fonts/`; do not duplicate them here. To republish the artifact, copy them back into the artifact's `fonts/` folder.
- Plus Jakarta Sans: the four `assets/fonts/PlusJakartaSans-*.ttf` files are a saved GitHub "Page not found" page, not fonts (see #973). The system names the family only; the app loads it from Google Fonts.
- The app icons: the files in `assets/icons` (the "Portfolio ring" shipped in #985). `system/assets/Logos/README.md` lists them and says which copies in the snapshot are stale.
- Generated files (`tokens.css`, the artifact's `api/` cards and `manifest.json`).

## Snapshot

Taken on 2026-10-11 from artifact version `1791699265-14b1`, which was checked against `main` at `3b7375ae`. Colour pairs that miss 4.5:1 are kept as drawn in the code and flagged in the token notes and in `system/README.md` (Contrast); they are the candidates for the UI/UX pass in #977.

`system/components/bundle.js`, `bundle.css` and the `preview.html` files are mock-up helpers: plain HTML/CSS equivalents of the Flutter widgets. They are not shipped in the app and need the artifact's generated `tokens.css` to render.

## Using it

- Before changing how a screen looks or flows, mock the change in this system (or in Claude Design) and link the mock in the PR. See `CLAUDE.md`.
- To refresh after a theme or widget change: update the Dart code first, then the artifact, then re-export the `project/` files into `system/` and update the snapshot line above.
