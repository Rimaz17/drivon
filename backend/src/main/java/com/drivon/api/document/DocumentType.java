package com.drivon.api.document;

/**
 * Kinds of vehicle documents from the product overview, plus {@link #OTHER} for papers that fit
 * none of them (e.g. an emission test certificate).
 */
public enum DocumentType {
  INSURANCE,
  REVENUE_LICENCE,
  REGISTRATION,
  INVOICE,
  RECEIPT,
  OTHER
}
