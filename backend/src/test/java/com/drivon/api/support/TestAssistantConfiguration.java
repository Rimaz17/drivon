package com.drivon.api.support;

import com.drivon.api.assistant.llm.LlmRouter;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;

/**
 * Integration tests never call a real AI provider: the router talks to two scripted models. Tests
 * reset them before scripting their turns.
 */
@TestConfiguration(proxyBeanMethods = false)
public class TestAssistantConfiguration {

  public static final String PRIMARY = "scriptedGemini";
  public static final String FALLBACK = "scriptedGroq";

  @Bean(PRIMARY)
  ScriptedLlmClient scriptedGemini() {
    return new ScriptedLlmClient("gemini");
  }

  @Bean(FALLBACK)
  ScriptedLlmClient scriptedGroq() {
    return new ScriptedLlmClient("groq");
  }

  @Bean
  @Primary
  LlmRouter scriptedRouter(ScriptedLlmClient scriptedGemini, ScriptedLlmClient scriptedGroq) {
    return new LlmRouter(scriptedGemini, scriptedGroq);
  }
}
