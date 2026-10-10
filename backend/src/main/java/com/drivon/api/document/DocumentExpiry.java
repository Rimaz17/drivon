package com.drivon.api.document;

import java.time.LocalDate;
import java.util.UUID;

/** The latest expiry date among a vehicle's documents of one type, and the document with it. */
public record DocumentExpiry(DocumentType type, UUID documentId, LocalDate expiryDate) {}
