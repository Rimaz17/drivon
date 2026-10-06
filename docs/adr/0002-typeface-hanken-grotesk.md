# 2. Typeface: Hanken Grotesk as the open-licence stand-in for Sequel Sans

- Status: Accepted
- Date: 2026-10-07

## Context

The visual inspiration specifies **Sequel Sans**, a commercial typeface that cannot be bundled in an open-source app. We need a free, open-licensed face that keeps its character: a neo-grotesque with compact proportions, tight tracking at display sizes, and a weight range from light to bold (the inspiration's large figures are set light and the headings medium).

Candidates considered: Hanken Grotesk, Albert Sans, Schibsted Grotesk and Inter Tight. Very common UI defaults (Inter, DM Sans, Space Grotesk, Plus Jakarta Sans and others) were excluded because they make the app look generic.

## Decision

Use **Hanken Grotesk 3.014** (SIL Open Font License 1.1), bundled as five static TTF weights (300, 400, 500, 600, 700) in `frontend/assets/fonts/hanken_grotesk/`, with its `OFL.txt`.

- Its closed, compact grotesque shapes and light weights are the closest free match to Sequel Sans.
- Static instances render the same on Android and iOS; variable-font weight mapping in Flutter is less predictable across platforms.
- It is bundled, not fetched at runtime, so text renders correctly offline and on first launch.

## Consequences

- About 370 KB is added to the app bundle. Only the weights used by the type scale are shipped.
- Large numbers use light weights with tabular figures (`FontFeature.tabularFigures`) so values line up in tiles and lists.
- If a licensed Sequel Sans becomes available, only `DrivonTypography.fontFamily` and the `pubspec.yaml` font entries change.
