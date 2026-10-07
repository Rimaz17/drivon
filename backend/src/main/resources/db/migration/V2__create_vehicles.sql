-- A user's vehicles (at most two per user, enforced in the service layer under
-- a user row lock). Registration numbers are normalized by the application
-- (upper case, single spaces, no spaces around hyphens) and unique per user.
CREATE TABLE vehicles (
    id                  UUID PRIMARY KEY,
    user_id             UUID        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    make                VARCHAR(50) NOT NULL,
    model               VARCHAR(50) NOT NULL,
    model_year          INTEGER     NOT NULL CHECK (model_year BETWEEN 1900 AND 2100),
    registration_number VARCHAR(20) NOT NULL,
    fuel_type           VARCHAR(20) NOT NULL CHECK (fuel_type IN ('PETROL', 'DIESEL', 'HYBRID')),
    current_odometer_km INTEGER     NOT NULL CHECK (current_odometer_km >= 0),
    created_at          TIMESTAMPTZ NOT NULL,
    updated_at          TIMESTAMPTZ NOT NULL,
    -- Leading user_id also serves the "vehicles of a user" lookup; no separate index needed.
    CONSTRAINT uk_vehicles_user_registration UNIQUE (user_id, registration_number)
);
