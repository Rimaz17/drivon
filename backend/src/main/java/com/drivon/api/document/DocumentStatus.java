package com.drivon.api.document;

/** Where a document's file is in the upload flow. */
public enum DocumentStatus {
  /** An upload URL was handed out; the file may not have arrived yet. Hidden from lists. */
  PENDING,
  /** The uploaded file was checked and the document is visible. */
  ACTIVE
}
