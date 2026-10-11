The app frame: the app bar, the Material 3 NavigationBar with its destinations, and the floating action button.

Use it for the five top-level areas. Everything deeper opens as a pushed screen with a back button.

## Anatomy

- App bar: `background` fill, no elevation or scroll tint, 56px (`app-bar-height`), left-aligned title in `h2` (Plus Jakarta Sans 20/600, `text`), 24px icon actions in 48dp buttons. The status-bar icons are dark in light and light in dark.
- NavigationBar: 70px (`nav-bar-height`), no elevation, no surface tint. `HomeShellScreen` overrides the theme's fill and indicator: the bar is `white` in light and `surface` (#0a0a0a, the page colour) in dark, not the theme's `card`, and the indicator is `primary` at 15% in both themes (the theme says 10% and 20%). Four destinations (Overview, Investments, Goals, Settings), five with Reports when its flag is on. Each shows a 24px icon and a 10px label (`tiny`). Unselected: outlined icon and label in `neutral-500-light` (`neutral-500-dark` in dark, the same hex). Selected: the filled icon in `primary`, a 600 label, and a pill indicator (Material 3's 64 x 32). `AppSizes.bottomNavHeight` (80) is not what is rendered.
- FAB: 56px, `radius-lg` 16, `primary` fill, `on-primary` icon, Material elevation 4; screens leave `fab-bottom-padding` 80 below the content.
- The theme also defines a `BottomNavigationBarTheme` (same colours, fixed type); the shell uses the NavigationBar.

## Consumer provides

`title`, `actions: [{ icon, label }]`, `items` (label, outlined and filled ligatures), `active`, `fab`.

## Rules

- The selected destination is the current page (`aria-current`); every item is at least 48dp.
- Labels are always shown: never icon-only navigation.
- Keep Overview first and Settings last.

## Contrast

Unselected labels `neutral-500-dark` on the dark bar (`surface`) are 4.13:1 (3.74:1 on `card`, the theme's own fill that the shell overrides) and 4.80:1 in light; the selected label on its 15% indicator is 5.06:1 in dark and 4.81:1 in light. Kept as drawn.

## Source

`app_theme.dart` (`appBarTheme`, `navigationBarTheme`, `bottomNavigationBarTheme`, `floatingActionButtonTheme`); `home_shell_screen.dart` (destinations and icons).
