package com.drivon.api.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.drivon.api.notification.FcmPushSender;
import com.drivon.api.notification.PushSender;
import com.drivon.api.notification.UnconfiguredPushSender;
import java.nio.charset.StandardCharsets;
import java.security.KeyPairGenerator;
import java.security.NoSuchAlgorithmException;
import java.util.Base64;
import org.junit.jupiter.api.Test;

class NotificationConfigTest {

  private final NotificationConfig config = new NotificationConfig();

  /** A service account file with a throwaway key; building the sender makes no network calls. */
  private static String fakeServiceAccount() throws NoSuchAlgorithmException {
    KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
    generator.initialize(2048);
    String key =
        Base64.getMimeEncoder(64, "\n".getBytes(StandardCharsets.US_ASCII))
            .encodeToString(generator.generateKeyPair().getPrivate().getEncoded());
    String pem =
        "-----BEGIN PRIVATE KEY-----\\n"
            + key.replace("\n", "\\n")
            + "\\n-----END PRIVATE KEY-----\\n";
    String json =
        """
        {"type": "service_account", "project_id": "drivon-test", "private_key_id": "abc",
         "private_key": "%s",
         "client_email": "firebase-adminsdk@drivon-test.iam.gserviceaccount.com",
         "client_id": "123", "token_uri": "https://oauth2.googleapis.com/token"}
        """
            .formatted(pem);
    return Base64.getEncoder().encodeToString(json.getBytes(StandardCharsets.UTF_8));
  }

  @Test
  void withoutAServiceAccountPushIsSwitchedOff() {
    PushSender sender = config.pushSender(new FirebaseProperties(" "));

    assertThat(sender).isInstanceOf(UnconfiguredPushSender.class);
    assertThat(sender.configured()).isFalse();
  }

  @Test
  void buildsTheFirebaseSenderFromABase64ServiceAccount() throws Exception {
    PushSender sender = config.pushSender(new FirebaseProperties(fakeServiceAccount()));

    assertThat(sender).isInstanceOf(FcmPushSender.class);
    assertThat(sender.configured()).isTrue();
    ((FcmPushSender) sender).close();
  }

  @Test
  void aValueThatIsNotBase64FailsStartupWithAClearMessage() {
    assertThatThrownBy(() -> config.pushSender(new FirebaseProperties("not base64 !!")))
        .isInstanceOf(IllegalStateException.class)
        .hasMessageContaining("FIREBASE_SERVICE_ACCOUNT_BASE64");
  }

  @Test
  void base64OfSomethingElseFailsStartupWithAClearMessage() {
    String notAnAccount = Base64.getEncoder().encodeToString("{\"hello\": 1}".getBytes());

    assertThatThrownBy(() -> config.pushSender(new FirebaseProperties(notAnAccount)))
        .isInstanceOf(IllegalStateException.class)
        .hasMessageContaining("service account");
  }
}
