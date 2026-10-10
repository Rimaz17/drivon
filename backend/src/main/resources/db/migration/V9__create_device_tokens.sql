-- Push notification tokens (Firebase Cloud Messaging), one row per app
-- installation. A user can have several devices; a token belongs to the user
-- who registered it last, so signing in as someone else on a phone moves it.
-- Tokens FCM reports as invalid are deleted. See
-- docs/adr/0013-reminders-and-notifications.md.
CREATE TABLE device_tokens (
    id            UUID PRIMARY KEY,
    user_id       UUID         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token         VARCHAR(512) NOT NULL,
    platform      VARCHAR(10)  NOT NULL CHECK (platform IN ('ANDROID', 'IOS')),
    registered_at TIMESTAMPTZ  NOT NULL,
    created_at    TIMESTAMPTZ  NOT NULL,
    updated_at    TIMESTAMPTZ  NOT NULL,
    CONSTRAINT uk_device_tokens_token UNIQUE (token)
);

CREATE INDEX idx_device_tokens_user_id ON device_tokens (user_id);
