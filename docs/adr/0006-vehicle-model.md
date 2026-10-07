# 6. Vehicle model and rules

- Status: Accepted
- Date: 2026-10-07

## Context

Phase 1 introduces vehicles: make, model, year, registration number, fuel type and current odometer (overview, section 8), with at most two vehicles per user and odometer readings that never go backwards.

## Decision

- **Table `vehicles`:** UUID key, `user_id` (foreign key, cascade on delete), `make`/`model` (≤ 50), `model_year` (`year` is a reserved word in SQL), `registration_number` (≤ 20), `fuel_type`, `current_odometer_km`, and audit timestamps. Database `CHECK` constraints back up the service rules.
- **Fuel types:** `PETROL`, `DIESEL`, `HYBRID`. Fuel tracking is in litres, so battery-electric vehicles are left out until charging (kWh) is modelled. Adding a value later only needs a migration that widens the check.
- **Two-vehicle limit:** enforced in `VehicleService` while holding a row lock on the user (`SELECT … FOR UPDATE`), so parallel requests cannot create a third vehicle. The API returns `422 VEHICLE_LIMIT_REACHED`.
- **Registration numbers:** normalized (upper case, single spaces, no spaces around hyphens) and **unique per user** (`409 REGISTRATION_NUMBER_IN_USE`). Two users may hold the same plate, for example after a sale.
- **Odometer:** an update may keep or increase `current_odometer_km`, but never lower it (`422 ODOMETER_DECREASE`). The overview's `OdometerReading` history, and an explicit correction flow for typos, arrive with fuel records in Phase 2, where readings are first recorded.
- **Model year:** 1900 up to next year, because next year's models are sold this year (`422 INVALID_MODEL_YEAR`).
- **Ownership:** every repository query includes the owner's ID. Another user's vehicle returns `404 VEHICLE_NOT_FOUND`, never 403, so IDs can't be probed.
- **Listing** is not paginated, unlike other list endpoints, because the business rule caps it at two items.
- **Selected vehicle:** the app keeps the selection on the device. The API stays stateless, and features that default to the selected vehicle receive its ID explicitly.

## Consequences

- Deleting a vehicle cascades to its records as later phases add them, so their migrations must use `ON DELETE CASCADE`.
- Correcting a too-high odometer reading isn't possible in Phase 1, except by deleting and re-adding the vehicle.
