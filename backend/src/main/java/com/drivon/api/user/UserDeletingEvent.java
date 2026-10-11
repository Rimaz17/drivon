package com.drivon.api.user;

import java.util.UUID;

/**
 * Published inside the transaction that deletes an account, just before the row goes. The database
 * cascades to everything the user owns; listeners clean up what lives elsewhere (document files).
 */
public record UserDeletingEvent(UUID userId) {}
