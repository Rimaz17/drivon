# 9. Maintenance, expenses and spending totals

- Status: Accepted
- Date: 2026-10-07

## Context

Phase 3 adds service records with a next service date and mileage, and expenses in the overview's categories (fuel, maintenance, repairs, insurance, parking, tolls, washing, other), with monthly, yearly, per-category and per-vehicle totals. Fill-ups (Phase 2) and services already carry what they cost. Entering them again as expenses would be tedious and would double-count.

## Decision

- **Table `maintenance_records`:** `service_type` (`OIL_CHANGE`, `GENERAL_SERVICE`, `TYRE_ROTATION`, `TYRE_REPLACEMENT`, `BRAKE_SERVICE`, `BATTERY_REPLACEMENT`, `WHEEL_ALIGNMENT`, `AIR_CONDITIONING`, `OTHER`), `serviced_on`, optional `odometer_km`, `cost` (0 allowed for warranty or free work), `notes`, optional `next_service_on` and `next_service_km`.
  - The odometer is optional because old receipts often lack it. When given, it joins the odometer timeline as a `MAINTENANCE` reading (ADR 0007) and follows the record through edits and deletion.
  - The next date must be after the service date (`422 NEXT_SERVICE_DATE_INVALID`). The next mileage must be above the service's odometer when one is given (`422 NEXT_SERVICE_KM_INVALID`, with `minKm`). Database `CHECK` constraints back both rules up.
- **Upcoming services** come from the latest record of each service type, found with `DISTINCT ON`. A newer oil change replaces the older one's due date. Each item has days and km remaining (from today in Sri Lanka and the vehicle's current odometer) and is overdue when either is negative. Overdue items sort first, then by due date, then services due only by mileage. A latest record without next fields means nothing is upcoming for that type. These are derived values; stored reminders with notifications come in Phase 6.
- **Table `expenses`:** `category`, `amount > 0`, `spent_on`, `notes`. All eight categories are accepted, so costs that aren't a logged fill-up or service (fuel for a jerry can, parts bought separately) still fit.
- **Spending totals combine all three sources:** fill-ups count as `FUEL`, services as `MAINTENANCE`, and expenses under their own category. Endpoints:
  - `GET /vehicles/{id}/spending?from&to`: every category's total and count for any range. The app's "this month", "this year" and "all time" are ranges.
  - `GET /vehicles/{id}/spending/monthly?months=`: zero-filled monthly totals.
  - `GET /spending/vehicles?from&to`: compares the user's vehicles.
  - Each source is summed with `SUM`/`GROUP BY` queries and the small result sets are merged in Java.
- Feature packages keep their repositories private. Fuel and maintenance expose `spendBetween`/`spendByMonth` for the spending service, which checks ownership before calling them.
- Services and expenses use the same client-generated IDs, paging and sort whitelists as fill-ups (ADR 0008).

## Consequences

- A fill-up never needs to be entered twice, and the per-category totals match the fuel and maintenance screens.
- An expense logged under `FUEL` or `MAINTENANCE` adds to those totals, which is right for costs that aren't fill-ups or services. The app explains this when one of those categories is chosen.
- Cost per km (Phase 5) can reuse these totals with the odometer timeline's distance.
