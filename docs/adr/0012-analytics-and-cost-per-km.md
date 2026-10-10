# 12. Analytics and cost per km

- Status: Accepted
- Date: 2026-10-10

## Context

Phase 5 needs analytics endpoints, a cost-per-km breakdown ("total operating cost / km driven, split into fuel, maintenance and other"), vehicle comparison ("Car Rs. 32/km vs Bike Rs. 8/km") and a dashboard with charts for fuel efficiency trends, monthly expenses, category split and cost trends. The pieces already exist: spending totals that combine fill-ups, services and expenses (ADR 0009), the odometer timeline (ADR 0007) and the full-tank efficiency calculator (ADR 0008).

## Decision

- **A separate `analytics` package composes the existing services** and stores nothing. It repeats none of their rules, so a figure on the dashboard always agrees with the Fuel, Service and Expenses tabs.
- **Distance driven** comes from the odometer timeline. Readings never decrease over time, so the odometer at the end of a day is the highest reading on or before it. A period's distance is that value at the period's end minus the value just before it starts. If the vehicle has no reading before the period (it was added during it), its first reading in the period is the start. Monthly distances come from one `GROUP BY` month query (`min`, `max`) plus the reading before the first month. Distance that crosses a month without readings is counted in the month of the reading that reveals it.
- **Cost per km** = everything spent in the period ÷ distance driven in the period, rounded half-up to the cent. It is `null` when no distance was recorded: a cost per zero km is meaningless, and the app explains why.
- **Groups:** `FUEL` (fill-ups and fuel expenses), `MAINTENANCE` (services plus maintenance and repairs expenses), `OTHER` (insurance, parking, tolls, washing, other). The breakdown always lists all three in that order, which keeps stacked charts stable.
- **Two cost-per-km figures exist on purpose:**
  - Fuel stats' `costPerKm` (ADR 0008): fuel burned per km over complete full-to-full tanks. It measures efficiency.
  - Analytics' `FUEL` cost per km: fuel *bought* in the period over distance *driven* in the period. It is the running-cost view, comparable with maintenance and other.
  - The two converge over long periods. The app labels them differently ("Fuel cost/km" on the Fuel tab, "Running cost" with its parts on Insights).
- **Endpoints** (all scoped to the signed-in user; another user's vehicle is `404 VEHICLE_NOT_FOUND`):
  - `GET /vehicles/{id}/analytics/cost-per-km?from&to`
  - `GET /vehicles/{id}/analytics/monthly-costs?months=1..24`: fuel, maintenance, other, total, distance and cost per km for each month, zero-filled.
  - `GET /vehicles/{id}/analytics/efficiency-trend?from&to`: one point per full-to-full tank (end date, distance, litres, km/L, fuel cost per km).
  - `GET /analytics/vehicle-comparison?from&to`: per vehicle, distance, total, cost per km with its parts, and average km/L.
  - The category split is the existing `GET /vehicles/{id}/spending`.
- All totals come from SQL aggregates. The only Java loops run over at most 24 months, 8 categories, 3 groups or 2 vehicles.

## Consequences

- No new tables or migrations; the dashboard is consistent with every other screen by construction.
- A vehicle with sparse odometer readings shows uneven monthly distances (a long gap lands in one month). Fill-ups and services add readings, so regular use smooths this out.
- The comparison runs the per-vehicle queries once per vehicle. That is fine with the two-vehicle limit and would need batching if the limit grows.
