package com.drivon.api.common.storage;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;

/** File storage is not set up on this server, or could not be reached. */
public class StorageUnavailableException extends DrivonException {

  public StorageUnavailableException(String detail) {
    super(ErrorCode.STORAGE_UNAVAILABLE, detail);
  }

  public StorageUnavailableException(String detail, Throwable cause) {
    this(detail);
    initCause(cause);
  }
}
