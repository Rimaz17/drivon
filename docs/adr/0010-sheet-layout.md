# 10. Two-layer screens: dark canvas and a paper sheet

- Status: Accepted
- Date: 2026-10-08

## Context

With every block as a dark tile on a near-black canvas, the tabs looked flat: tiles barely separated from the background and the lower half of the garage was empty. A newer inspiration board shows the same dark tiles laid on a warm off-white sheet with rounded top corners, and a vehicle switcher drawn as a light pill sliding in a dark track. The contrast between dark tiles and light paper gives the screen a clear structure. The canvas was also deepened to a darker near-black at the user's request.

## Decision

- Each tab body is a `SheetScrollView`: the greeting, vehicle switcher and the tab's one headline card stay on the canvas; everything else sits on a paper sheet (`#F3F2EF`) that runs to the bottom of the screen even when the content is short.
- Content placed directly on the sheet (headings, record rows, chips, buttons) gets a second theme, `DrivonTheme.paper()`, built by the same builder as the dark theme with its own color scheme and `DrivonColors.paper`. Status colors are deepened so text stays WCAG AA on paper; the contrast test covers both themes.
- `DrivonCard` switches back to the app's dark theme when it is on a sheet, using the slightly deeper `#1C1D1F`. Card content must read the theme below the card (a `Builder` or its own widget), which `StatTile`, `MonthlySpendCard` and the Expenses cards now do.
- `PillSegmentedControl` replaces Material's `SegmentedButton` for the vehicle switcher and the Expenses period: a dark track with a lilac (`#D9CCFF`) thumb that slides between options.
- The garage sheet shows figures the app already has: average km/L, fuel cost per km, the next service, this month's spending, fuel type and model year.

## Consequences

- Widgets on a sheet must not carry styles taken from the screen's context, or canvas colors end up on the paper. `SectionTitle` and `Builder`s handle the current cases.
- The paper hides the scaffold's ink layer, so the sheet gives each child its own transparent `Material` for ripples.
- `SliverFillRemaining` fails inside a sliver group once content outgrows the screen, so the sheet computes its own filler height.
- The handle at the top of the sheet is decorative; the sheet does not drag.
- The garage now loads fuel, service and spending figures; while they load or if they fail, tiles show a dash and a short caption instead of moving the layout.
