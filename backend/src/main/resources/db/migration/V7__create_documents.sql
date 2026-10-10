-- Vehicle documents (insurance, revenue licence, registration, invoices,
-- receipts). The file itself lives in the private R2 bucket under file_key;
-- the bucket is never listed. A row starts PENDING when the app asks for an
-- upload URL and becomes ACTIVE once the API has checked the uploaded object.
-- See docs/adr/0011-documents-on-r2.md.
CREATE TABLE documents (
    id           UUID PRIMARY KEY,
    vehicle_id   UUID         NOT NULL REFERENCES vehicles (id) ON DELETE CASCADE,
    type         VARCHAR(20)  NOT NULL CHECK (type IN (
                     'INSURANCE', 'REVENUE_LICENCE', 'REGISTRATION', 'INVOICE', 'RECEIPT',
                     'OTHER')),
    issued_on    DATE,
    expires_on   DATE,
    notes        VARCHAR(500),
    file_key     VARCHAR(255) NOT NULL UNIQUE,
    content_type VARCHAR(50)  NOT NULL CHECK (content_type IN (
                     'image/jpeg', 'image/png', 'application/pdf')),
    -- 5 MB upload limit.
    size_bytes   INTEGER      NOT NULL CHECK (size_bytes BETWEEN 1 AND 5242880),
    status       VARCHAR(10)  NOT NULL CHECK (status IN ('PENDING', 'ACTIVE')),
    created_at   TIMESTAMPTZ  NOT NULL,
    updated_at   TIMESTAMPTZ  NOT NULL,
    CONSTRAINT ck_documents_expiry_after_issue CHECK (expires_on > issued_on)
);

-- Serves a vehicle's document list and the expiring-soon query.
CREATE INDEX idx_documents_vehicle_status_expires ON documents (vehicle_id, status, expires_on);
