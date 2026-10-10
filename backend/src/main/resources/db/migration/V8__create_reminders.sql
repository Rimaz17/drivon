-- Reminders: when something on a vehicle is next due, by date, by mileage or
-- by whichever comes first. SERVICE reminders mirror the latest service record
-- of each type that sets a next date or mileage; DOCUMENT reminders mirror the
-- latest expiry date of each document type; MANUAL reminders are the user's own.
-- notified_stage and last_notified_at make the notification job idempotent:
-- each stage (due soon, due) is pushed at most once per due date and mileage.
-- See docs/adr/0013-reminders-and-notifications.md.
CREATE TABLE reminders (
    id               UUID PRIMARY KEY,
    vehicle_id       UUID        NOT NULL REFERENCES vehicles (id) ON DELETE CASCADE,
    source           VARCHAR(10) NOT NULL CHECK (source IN ('MANUAL', 'SERVICE', 'DOCUMENT')),
    service_type     VARCHAR(30) CHECK (service_type IN (
                         'OIL_CHANGE', 'GENERAL_SERVICE', 'TYRE_ROTATION', 'TYRE_REPLACEMENT',
                         'BRAKE_SERVICE', 'BATTERY_REPLACEMENT', 'WHEEL_ALIGNMENT',
                         'AIR_CONDITIONING', 'OTHER')),
    document_type    VARCHAR(20) CHECK (document_type IN (
                         'INSURANCE', 'REVENUE_LICENCE', 'REGISTRATION', 'INVOICE', 'RECEIPT',
                         'OTHER')),
    -- The service record or document the reminder follows.
    source_id        UUID,
    title            VARCHAR(80),
    due_on           DATE,
    due_km           INTEGER     CHECK (due_km BETWEEN 1 AND 2000000),
    notified_stage   VARCHAR(10) NOT NULL CHECK (notified_stage IN ('NONE', 'DUE_SOON', 'DUE')),
    last_notified_at TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL,
    updated_at       TIMESTAMPTZ NOT NULL,
    CONSTRAINT ck_reminders_due CHECK (due_on IS NOT NULL OR due_km IS NOT NULL),
    CONSTRAINT ck_reminders_source CHECK (
        (source = 'MANUAL' AND title IS NOT NULL AND service_type IS NULL
            AND document_type IS NULL AND source_id IS NULL)
        OR (source = 'SERVICE' AND service_type IS NOT NULL AND document_type IS NULL
            AND source_id IS NOT NULL AND title IS NULL)
        OR (source = 'DOCUMENT' AND document_type IS NOT NULL AND service_type IS NULL
            AND source_id IS NOT NULL AND title IS NULL AND due_km IS NULL))
);

-- At most one automatic reminder per service type and per document type.
CREATE UNIQUE INDEX uk_reminders_vehicle_service ON reminders (vehicle_id, service_type)
    WHERE source = 'SERVICE';
CREATE UNIQUE INDEX uk_reminders_vehicle_document ON reminders (vehicle_id, document_type)
    WHERE source = 'DOCUMENT';
CREATE INDEX idx_reminders_vehicle ON reminders (vehicle_id);
-- The notification job only looks at reminders whose last stage wasn't sent.
CREATE INDEX idx_reminders_pending ON reminders (due_on) WHERE notified_stage <> 'DUE';
