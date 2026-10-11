package com.drivon.api.user;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.test.util.ReflectionTestUtils;

class UserServiceTest {

  private static final UUID USER = UUID.randomUUID();

  private final UserRepository users = mock(UserRepository.class);
  private final ApplicationEventPublisher events = mock(ApplicationEventPublisher.class);
  private final UserService service = new UserService(users, events);

  private User existing() {
    User user = new User("Rimaz", "rimaz@example.com", "hash");
    ReflectionTestUtils.setField(user, "id", USER);
    when(users.findById(USER)).thenReturn(Optional.of(user));
    when(users.saveAndFlush(user)).thenReturn(user);
    return user;
  }

  @Test
  void updatesTheProfileWithTrimmedNameAndNormalizedEmail() {
    existing();

    UserResponse response =
        service.updateProfile(
            USER, new UpdateProfileRequest("  Rimaz Saththar ", " New@Example.COM "));

    assertThat(response.name()).isEqualTo("Rimaz Saththar");
    assertThat(response.email()).isEqualTo("new@example.com");
  }

  @Test
  void keepingTheSameEmailInAnotherCaseIsNotAConflict() {
    existing();

    UserResponse response =
        service.updateProfile(USER, new UpdateProfileRequest("Rimaz", "RIMAZ@example.com"));

    assertThat(response.email()).isEqualTo("rimaz@example.com");
    verify(users, never()).existsByEmail(anyString());
  }

  @Test
  void rejectsAnEmailThatAnotherAccountUses() {
    User user = existing();
    when(users.existsByEmail("taken@example.com")).thenReturn(true);

    assertThatThrownBy(
            () -> service.updateProfile(USER, new UpdateProfileRequest("R", "Taken@example.com")))
        .extracting(e -> ((DrivonException) e).code())
        .isEqualTo(ErrorCode.EMAIL_ALREADY_REGISTERED);
    assertThat(user.getEmail()).isEqualTo("rimaz@example.com");
    verify(users, never()).saveAndFlush(any());
  }

  @Test
  void updatingADeletedAccountIsUnauthenticated() {
    when(users.findById(USER)).thenReturn(Optional.empty());

    assertThatThrownBy(
            () -> service.updateProfile(USER, new UpdateProfileRequest("R", "r@example.com")))
        .extracting(e -> ((DrivonException) e).code())
        .isEqualTo(ErrorCode.UNAUTHENTICATED);
  }

  @Test
  void announcesTheDeletionBeforeRemovingTheAccount() {
    User user = existing();

    service.delete(USER);

    InOrder order = inOrder(events, users);
    order.verify(events).publishEvent(new UserDeletingEvent(USER));
    order.verify(users).delete(user);
  }
}
