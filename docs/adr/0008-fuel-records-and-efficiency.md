# 8. Fuel records, efficiency and exact decimals

- Status: Accepted
- Date: 2026-10-07

## Context

Phase 2 logs fill-ups (litres, amount, price per litre, odometer, station, date, full or partial) and must calculate km/L, average km/L, fuel cost per km, and monthly and total fuel spend. The backend is the single source of truth for these numbers. Fill-ups will later be drafted offline (Phase 8), so creating one must be safe to retry.

## Decision

- **Table `fuel_records`:** `litres NUMERIC(7,3)` (pumps show three decimals), `amount NUMERIC(12,2)`, `price_per_litre NUMERIC(10,2)`, `odometer_km`, `filled_on`, `full_tank`, optional `station`. Each fill-up's odometer also sits on the vehicle's odometer timeline (ADR 0007).
- **Price per litre** is optional in requests. When it is left out, it is derived as amount ÷ litres. When it is sent, litres × price must match the amount to within 1% (at least Rs. 1), because pumps round the amount. Otherwise the request fails with `422 FUEL_PRICE_MISMATCH` and the expected amount.
- **Efficiency (full-tank method):** fill-ups are taken in odometer order. Each pair of consecutive full fills forms a stretch: its distance divided by all litres added after the first fill (partial fills plus the closing full fill) is its km/L. Fills before the first full fill are ignored, partial fills after the last one wait for the next full fill, and zero-distance stretches are skipped. Values are rounded half-up to two decimals.
- **Aggregates:** average km/L is total distance ÷ total litres over the stretches (weighted by distance, not a mean of ratios). Fuel cost per km is the cost of the fuel burned over those stretches ÷ their distance. For a date range, the stretches that *ended* in the range count. Spend, litres and fill-up counts come from `SUM`/`COUNT` queries, and monthly spend from a `GROUP BY` month query, zero-filled.
- **Nothing derived is stored.** km/L is recalculated from a lightweight projection of the vehicle's fill-ups on each request, so editing or deleting any fill-up can never leave a stale figure. A personal vehicle has at most a few hundred fill-ups a year.
- **Decimals are JSON strings** (`"10950.00"`), for every `BigDecimal` in the API. JSON numbers are parsed as binary floating point by most clients (including Dart), which can't represent money exactly. Requests may send strings or numbers.
- **Client-generated IDs:** a create may carry an `id`. If it was already saved for the same vehicle, the saved record is returned with `200` instead of a duplicate. If it belongs to another vehicle, the result is `409 RECORD_ID_CONFLICT`. New records always insert (the entity implements `Persistable`), so an ID can never overwrite another row.
- **Lists** are paginated (`page`, `size` ≤ 100) and sort only by whitelisted API field names (`400 INVALID_SORT` otherwise). They are newest first by default.

## Consequences

- Efficiency is always consistent with the data, at the cost of reading one projection per request. If this ever becomes slow, it can be cached per vehicle and invalidated on writes.
- A forgotten fill-up between two full fills overstates that stretch's km/L. Detecting it would need a "missed fill-up" flag, which the overview doesn't include.
- Clients must parse decimal strings. The Flutter app keeps them as integers of the smallest unit (cents, millilitres) and never as `double`.
