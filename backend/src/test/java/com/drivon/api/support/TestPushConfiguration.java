package com.drivon.api.support;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;

/** Integration tests never reach Firebase; pushes are recorded instead. */
@TestConfiguration(proxyBeanMethods = false)
public class TestPushConfiguration {

  @Bean
  @Primary
  RecordingPushSender recordingPushSender() {
    return new RecordingPushSender();
  }
}
