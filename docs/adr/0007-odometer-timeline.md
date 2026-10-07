# 7. Odometer timeline and corrections

- Status: Accepted
- Date: 2026-10-07

## Context

The overview's data model has an `OdometerReading` (vehicle, reading, date, source), and the project rules say odometer readings can't go backwards except through an explicit correction. Phase 1 only had `vehicles.current_odometer_km`, which could only increase (ADR 0006). Phase 2 adds fill-ups, and Phase 3 adds services, each carrying an odometer value. Users also log past fill-ups after the fact, so "never lower than the current odometer" is too strict for back-dated records.

## Decision

- **Table `odometer_readings`:** `vehicle_id`, `reading_km`, `recorded_on` (a calendar date), `source` (`INITIAL`, `MANUAL`, `FUEL`, `MAINTENANCE`) and `source_id` (the fill-up or service the reading belongs to, unique). Readings cascade with their vehicle.
- **Ordering rule:** a reading may not be lower than any reading on an *earlier* date, or higher than any reading on a *later* date. Readings on the same date may be in any order, because the time of day isn't recorded (two fill-ups on one day can be entered in either order). Violations return `422 ODOMETER_OUT_OF_ORDER` with `minKm` and/or `maxKm` in the Problem Details body.
- **Current odometer:** `vehicles.current_odometer_km` always equals the highest reading. It is updated whenever a reading is added, moved or removed, so deleting a fill-up that held the highest reading lowers it again.
- **Sources:**
  - `INITIAL`: the odometer a vehicle was added with, dated the day it was added. It can be corrected but not deleted, so every vehicle keeps at least one reading. A migration backfills one for existing vehicles, dated on the day their odometer was last saved.
  - `MANUAL`: entered in the odometer history, or created when the vehicle form raises the odometer (dated today). These can be corrected and deleted.
  - `FUEL` / `MAINTENANCE`: owned by a fill-up or service and changed only through that record (`422 ODOMETER_READING_LOCKED` otherwise), so the two never disagree.
- **Corrections:** `PUT /vehicles/{id}/odometer-readings/{readingId}` on an initial or manual reading is the explicit way to fix a typo, and the only way the current odometer can go down. The vehicle form still rejects a lower odometer (`ODOMETER_DECREASE`).
- **Concurrency:** every odometer-changing write locks the vehicle row (`SELECT … FOR UPDATE`) before checking the ordering rule, so two parallel fill-ups can't both slip past it.
- **Dates** are Sri Lankan calendar dates (`Asia/Colombo`), and readings can't be dated in the future (`422 DATE_IN_FUTURE`).

## Consequences

- One query each for the highest earlier and lowest later reading (indexed on `vehicle_id, recorded_on`) keeps the check cheap.
- Fill-ups and services store their odometer twice (their own column and the linked reading). The services that write them keep both in one transaction.
- Same-day ordering isn't enforced, so a same-day reading lower than another one is accepted. Efficiency calculations sort fill-ups by odometer, so they stay correct.
- Distance driven in a period (Phase 5, and the assistant's `getOdometerStats`) can be read from this timeline.
