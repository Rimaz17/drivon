package com.drivon.api.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.HttpStatusEntryPoint;

/**
 * Stateless API security baseline. Only health, info and API docs are public; every other endpoint
 * requires authentication (JWT authentication is added in Phase 1).
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

  private static final String[] PUBLIC_PATHS = {
    "/actuator/health",
    "/actuator/health/**",
    "/actuator/info",
    "/v3/api-docs",
    "/v3/api-docs/**",
    "/swagger-ui.html",
    "/swagger-ui/**"
  };

  @Bean
  SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
    return http
        // Bearer tokens are sent explicitly, never via cookies, so CSRF does not apply.
        .csrf(AbstractHttpConfigurer::disable)
        .sessionManagement(
            session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .httpBasic(AbstractHttpConfigurer::disable)
        .formLogin(AbstractHttpConfigurer::disable)
        .logout(AbstractHttpConfigurer::disable)
        .exceptionHandling(
            exceptions ->
                exceptions.authenticationEntryPoint(
                    new HttpStatusEntryPoint(HttpStatus.UNAUTHORIZED)))
        .authorizeHttpRequests(
            auth -> auth.requestMatchers(PUBLIC_PATHS).permitAll().anyRequest().authenticated())
        .build();
  }
}
