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
   * Changes the user's name and email. The email stays unique across accounts, compared after
   * normalization, so changing only its case is allowed.
   */
  @Transactional
  public UserResponse updateProfile(UUID userId, UpdateProfileRequest request) {
    User user =
        users.findById(userId).orElseThrow(() -> new DrivonException(ErrorCode.UNAUTHENTICATED));
    String email = Emails.normalize(request.email());
    if (!email.equals(user.getEmail()) && users.existsByEmail(email)) {
      throw new DrivonException(
          ErrorCode.EMAIL_ALREADY_REGISTERED, "An account with this email already exists.");
    }
    user.updateProfile(request.name().strip(), email);
    // Flush so a unique-constraint race surfaces here, as a conflict.
    return UserResponse.from(users.saveAndFlush(user));
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
