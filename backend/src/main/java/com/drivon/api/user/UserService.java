package com.drivon.api.user;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UserService {

  private final UserRepository users;

  public UserService(UserRepository users) {
    this.users = users;
  }

  /** The signed-in user's profile. A token for a deleted account counts as unauthenticated. */
  @Transactional(readOnly = true)
  public UserResponse getProfile(UUID userId) {
    return users
        .findById(userId)
        .map(UserResponse::from)
        .orElseThrow(() -> new DrivonException(ErrorCode.UNAUTHENTICATED));
  }

  /**
   * Locks the user's row for the rest of the caller's transaction, so concurrent requests that
   * check a per-user limit (such as the vehicle count) run one at a time.
   */
  @Transactional(propagation = Propagation.MANDATORY)
  public void lockForUpdate(UUID userId) {
    users
        .findByIdForUpdate(userId)
        .orElseThrow(() -> new DrivonException(ErrorCode.UNAUTHENTICATED));
  }
}
