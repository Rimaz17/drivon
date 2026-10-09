package com.drivon.api.common.storage;

import org.jspecify.annotations.Nullable;

/** What the storage service reports about an uploaded object. */
public record StoredObject(long sizeBytes, @Nullable String contentType) {}
