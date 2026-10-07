# 4. Design tokens derived from the inspiration boards

- Status: Accepted
- Date: 2026-10-07

## Context

Drivon's look comes from inspiration boards for a different app: a dark UI with soft rounded tiles, light pastel highlight cards, a violet-to-mint gradient gauge and a light grotesque typeface. Only the visual language is reused, not content, logos or imagery. Colors were sampled from the images' pixels rather than taken from their labels.

One discrepancy: the palette board labels its main swatch `#E72068` (a magenta), but the swatch and the matching star motif render as **`#7D56EE`** (a violet). The violet is what appears throughout the app mockups, so it is the brand primary. The magenta survives as the family for the danger color, which matches the mockups' pink "bad metric" highlights.

## Decision

Tokens live in `frontend/lib/design_system/` and are the single source of truth.

| Role | Value | Notes |
|---|---|---|
| Canvas | `#0B0B0D` | Deep near-black, darker than the mockups at the user's request (never pure black) |
| Card / raised / high | `#242427` / `#2E2F32` / `#393A3E` | Tonal surfaces instead of shadows |
| Primary | `#7D56EE` | Filled buttons, active states; white text on it passes AA |
| Primary text on dark | `#B9A3FF` | Links, focused input borders, cursor |
| Mint | `#99E7D8` | Success and positive metrics, secondary color |
| Lavender highlight | `#F3C7F8` | The one card per screen that needs attention, with dark text |
| Sky | `#D7EFFF` | Secondary call-to-action fill, with dark text |
| Danger | `#FF6E96` | Lightened from the brand magenta for AA contrast on dark |
| Warning | `#F6C177` | |
| Text | `#F4F4F6` / `#A8AAAE` / `#9A9CA2` | Primary / secondary / tertiary, all AA on every surface |
| Signature gradient | violet → orchid → lavender → mint | Gauges and hero cards only, never on text |

- **Type scale:** Material 3 roles in Hanken Grotesk (ADR 0002); display sizes are light with negative tracking, and numeric styles use tabular figures.
- **Spacing:** a 4-point scale (2–48), 20 dp screen gutters, 48 dp minimum touch targets.
- **Radii:** 6 / 10 / 14 / 20 / 28 and pill; cards use 20 and buttons and chips are pills.
- **Motion:** 150 / 250 / 450 ms with ease-out curves, no bounce, and reduced motion respected.
- **Dark theme first.** Semantic colors sit in a `ThemeExtension` (`DrivonColors`) next to a full `ColorScheme`, so a light theme only needs a second set of values.

## Consequences

- A unit test asserts WCAG AA contrast for every text/surface pair and for text on brand fills; it caught and fixed a too-dim tertiary text color during setup.
- Feature code must use the tokens and components, never literal colors or sizes.
- Purple-to-blue gradients, nested cards and gray text on colored fills stay out of the visual language.
