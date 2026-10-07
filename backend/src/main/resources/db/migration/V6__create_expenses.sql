-- Running costs other than fill-ups and services (insurance, parking, tolls,
-- washing, repairs, ...). Spending totals add fill-ups (as FUEL) and services
-- (as MAINTENANCE) to these. See docs/adr/0009-maintenance-expenses-and-spending.md.
CREATE TABLE expenses (
    id         UUID PRIMARY KEY,
    vehicle_id UUID           NOT NULL REFERENCES vehicles (id) ON DELETE CASCADE,
    category   VARCHAR(20)    NOT NULL CHECK (category IN (
                   'FUEL', 'MAINTENANCE', 'REPAIRS', 'INSURANCE', 'PARKING', 'TOLLS',
                   'WASHING', 'OTHER')),
    amount     NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    spent_on   DATE           NOT NULL,
    notes      VARCHAR(500),
    created_at TIMESTAMPTZ    NOT NULL,
    updated_at TIMESTAMPTZ    NOT NULL
);

-- Serves per-vehicle history (newest first) and date-range totals.
CREATE INDEX idx_expenses_vehicle_spent_on ON expenses (vehicle_id, spent_on);
