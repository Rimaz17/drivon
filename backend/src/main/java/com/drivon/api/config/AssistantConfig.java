package com.drivon.api.config;

import com.drivon.api.assistant.llm.GeminiClient;
import com.drivon.api.assistant.llm.GroqClient;
import com.drivon.api.assistant.llm.LlmClient;
import com.drivon.api.assistant.llm.LlmRouter;
import java.net.http.HttpClient;
import java.time.Duration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.RestClient;
import tools.jackson.databind.json.JsonMapper;

/** Builds the AI providers and the router that fails over between them. */
@Configuration
public class AssistantConfig {

  private static final Logger log = LoggerFactory.getLogger(AssistantConfig.class);

  private static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(10);

  @Bean
  LlmRouter llmRouter(AssistantProperties properties, JsonMapper json) {
    HttpClient httpClient = HttpClient.newBuilder().connectTimeout(CONNECT_TIMEOUT).build();
    JdkClientHttpRequestFactory requests = new JdkClientHttpRequestFactory(httpClient);
    requests.setReadTimeout(properties.callTimeout());
    RestClient.Builder http = RestClient.builder().requestFactory(requests);

    AssistantProperties.ProviderSettings gemini = properties.gemini();
    AssistantProperties.ProviderSettings groq = properties.groq();
    LlmClient geminiClient =
        new GeminiClient(http.clone(), json, gemini.baseUrl(), gemini.apiKey(), gemini.model());
    LlmClient groqClient =
        new GroqClient(http.clone(), json, groq.baseUrl(), groq.apiKey(), groq.model());
    if (!geminiClient.configured() && !groqClient.configured()) {
      log.warn(
          "No AI provider is configured (GEMINI_API_KEY, GROQ_API_KEY); Ask My Vehicle is off");
    }
    return properties.primary() == AssistantProperties.Provider.GEMINI
        ? new LlmRouter(geminiClient, groqClient)
        : new LlmRouter(groqClient, geminiClient);
  }
}
