-- Each vehicle's odometer timeline: the reading it was added with, readings the
-- user enters, and the odometer of every fill-up (and later every service).
-- A reading may not be lower than one on an earlier date or higher than one on
-- a later date; the vehicle's current odometer is the highest reading.
-- See docs/adr/0007-odometer-timeline.md.
CREATE TABLE odometer_readings (
    id          UUID PRIMARY KEY,
    vehicle_id  UUID        NOT NULL REFERENCES vehicles (id) ON DELETE CASCADE,
    reading_km  INTEGER     NOT NULL CHECK (reading_km BETWEEN 0 AND 2000000),
    recorded_on DATE        NOT NULL,
    source      VARCHAR(20) NOT NULL CHECK (source IN ('INITIAL', 'MANUAL', 'FUEL', 'MAINTENANCE')),
    -- The fill-up or service the reading belongs to; only those sources have one.
    source_id   UUID,
    created_at  TIMESTAMPTZ NOT NULL,
    updated_at  TIMESTAMPTZ NOT NULL,
    CONSTRAINT uk_odometer_readings_source_id UNIQUE (source_id),
    CONSTRAINT ck_odometer_readings_source_link
        CHECK ((source IN ('FUEL', 'MAINTENANCE')) = (source_id IS NOT NULL))
);

-- Serves the per-vehicle timeline lookups (readings before or after a date).
CREATE INDEX idx_odometer_readings_vehicle_date ON odometer_readings (vehicle_id, recorded_on);

-- Existing vehicles start their timeline with their current odometer, dated on
-- the day it was last saved (Sri Lankan calendar date).
INSERT INTO odometer_readings
    (id, vehicle_id, reading_km, recorded_on, source, source_id, created_at, updated_at)
SELECT gen_random_uuid(),
       id,
       current_odometer_km,
       (updated_at AT TIME ZONE 'Asia/Colombo')::date,
       'INITIAL',
       NULL,
       updated_at,
       updated_at
FROM vehicles;
