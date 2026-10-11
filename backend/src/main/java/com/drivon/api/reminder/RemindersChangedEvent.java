package com.drivon.api.reminder;

import java.util.UUID;

/**
 * Published inside the transaction that adds or changes a vehicle's reminders. After it commits,
 * {@link ReminderNotifier} checks whether any of them is already due.
 */
record RemindersChangedEvent(UUID vehicleId) {}
