package com.drivon.api.assistant.llm;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.drivon.api.support.ScriptedLlmClient;
import java.util.List;
import org.junit.jupiter.api.Test;

class LlmRouterTest {

  private static final LlmRequest REQUEST =
      new LlmRequest("system", List.of(new LlmMessage.User("Hi")), List.of());

  private final ScriptedLlmClient primary = new ScriptedLlmClient("gemini");
  private final ScriptedLlmClient fallback = new ScriptedLlmClient("groq");
  private final LlmRouter router = new LlmRouter(primary, fallback);

  @Test
  void usesThePrimaryWhileItWorks() {
    primary.thenAnswer("one").thenAnswer("two");

    LlmRouter.Conversation conversation = router.conversation();

    assertThat(conversation.complete(REQUEST).text()).isEqualTo("one");
    assertThat(conversation.complete(REQUEST).text()).isEqualTo("two");
    assertThat(fallback.requests()).isEmpty();
  }

  @Test
  void retriesOnceWithTheFallbackAndStaysWithIt() {
    primary.thenFail("gemini answered HTTP 429");
    fallback.thenAnswer("from groq").thenAnswer("groq again");

    LlmRouter.Conversation conversation = router.conversation();

    assertThat(conversation.complete(REQUEST).text()).isEqualTo("from groq");
    assertThat(conversation.complete(REQUEST).text()).isEqualTo("groq again");
    assertThat(primary.requests()).hasSize(1);
    // A new question tries the primary again.
    primary.thenAnswer("back");
    assertThat(router.conversation().complete(REQUEST).text()).isEqualTo("back");
  }

  @Test
  void anUnexpectedErrorAlsoFailsOver() {
    primary.then(
        request -> {
          throw new IllegalStateException("bug");
        });
    fallback.thenAnswer("fine");

    assertThat(router.conversation().complete(REQUEST).text()).isEqualTo("fine");
  }

  @Test
  void failsWhenBothFail() {
    primary.thenFail("down");
    fallback.thenFail("also down");

    assertThatThrownBy(() -> router.conversation().complete(REQUEST))
        .isInstanceOf(LlmException.class)
        .hasMessage("also down");
  }

  @Test
  void skipsAProviderWithoutAKey() {
    primary.configured(false);
    fallback.thenAnswer("only groq");

    assertThat(router.available()).isTrue();
    assertThat(router.conversation().complete(REQUEST).text()).isEqualTo("only groq");
    assertThat(primary.requests()).isEmpty();
  }

  @Test
  void withoutAFallbackThePrimaryFailureIsReported() {
    fallback.configured(false);
    primary.thenFail("gemini answered HTTP 500");

    assertThatThrownBy(() -> router.conversation().complete(REQUEST))
        .isInstanceOf(LlmException.class)
        .hasMessageContaining("500");
  }

  @Test
  void isUnavailableWithoutKeys() {
    primary.configured(false);
    fallback.configured(false);

    assertThat(router.available()).isFalse();
    assertThatThrownBy(() -> router.conversation().complete(REQUEST))
        .isInstanceOf(LlmException.class);
  }
}
