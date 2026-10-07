-- Services and repairs done on a vehicle. The odometer is optional (old
-- receipts often lack it); when present it also sits on the vehicle's odometer
-- timeline (odometer_readings, source MAINTENANCE). The next service date and
-- mileage drive the "upcoming service" list and, later, reminders.
-- See docs/adr/0009-maintenance-expenses-and-spending.md.
CREATE TABLE maintenance_records (
    id              UUID PRIMARY KEY,
    vehicle_id      UUID           NOT NULL REFERENCES vehicles (id) ON DELETE CASCADE,
    service_type    VARCHAR(30)    NOT NULL CHECK (service_type IN (
                        'OIL_CHANGE', 'GENERAL_SERVICE', 'TYRE_ROTATION', 'TYRE_REPLACEMENT',
                        'BRAKE_SERVICE', 'BATTERY_REPLACEMENT', 'WHEEL_ALIGNMENT',
                        'AIR_CONDITIONING', 'OTHER')),
    serviced_on     DATE           NOT NULL,
    odometer_km     INTEGER        CHECK (odometer_km BETWEEN 0 AND 2000000),
    cost            NUMERIC(12, 2) NOT NULL CHECK (cost >= 0),
    notes           VARCHAR(500),
    next_service_on DATE,
    next_service_km INTEGER        CHECK (next_service_km BETWEEN 1 AND 2000000),
    created_at      TIMESTAMPTZ    NOT NULL,
    updated_at      TIMESTAMPTZ    NOT NULL,
    CONSTRAINT ck_maintenance_next_date CHECK (next_service_on > serviced_on),
    CONSTRAINT ck_maintenance_next_km CHECK (next_service_km > odometer_km)
);

-- Serves per-vehicle history (newest first), date-range totals and the
-- latest record of each service type.
CREATE INDEX idx_maintenance_vehicle_serviced_on ON maintenance_records (vehicle_id, serviced_on);
CREATE INDEX idx_maintenance_vehicle_type ON maintenance_records (vehicle_id, service_type);
