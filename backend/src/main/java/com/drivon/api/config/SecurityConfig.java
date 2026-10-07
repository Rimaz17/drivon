package com.drivon.api.config;

import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.server.resource.web.BearerTokenResolver;
import org.springframework.security.oauth2.server.resource.web.DefaultBearerTokenResolver;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.web.servlet.HandlerExceptionResolver;

/**
 * Stateless JWT security. Health, info, API docs and the auth endpoints are public; everything else
 * needs a valid bearer access token. Security errors are rendered by the same Problem Details
 * handler as every other error.
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

  static final String AUTH_PATH_PREFIX = "/api/v1/auth/";

  private static final String[] PUBLIC_PATHS = {
    "/actuator/health",
    "/actuator/health/**",
    "/actuator/info",
    "/v3/api-docs",
    "/v3/api-docs/**",
    "/swagger-ui.html",
    "/swagger-ui/**",
    "/error"
  };

  @Bean
  SecurityFilterChain securityFilterChain(
      HttpSecurity http,
      AuthenticationEntryPoint problemDetailsEntryPoint,
      AccessDeniedHandler problemDetailsAccessDeniedHandler)
      throws Exception {
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
                exceptions
                    .authenticationEntryPoint(problemDetailsEntryPoint)
                    .accessDeniedHandler(problemDetailsAccessDeniedHandler))
        .oauth2ResourceServer(
            oauth2 ->
                oauth2
                    .jwt(Customizer.withDefaults())
                    .bearerTokenResolver(bearerTokenResolver())
                    .authenticationEntryPoint(problemDetailsEntryPoint))
        .authorizeHttpRequests(
            auth ->
                auth.requestMatchers(PUBLIC_PATHS)
                    .permitAll()
                    .requestMatchers(HttpMethod.POST, AUTH_PATH_PREFIX + "**")
                    .permitAll()
                    .anyRequest()
                    .authenticated())
        .build();
  }

  /**
   * Ignores the Authorization header on the auth endpoints, so a client refreshing with an expired
   * access token still attached is not rejected before reaching the refresh logic.
   */
  private static BearerTokenResolver bearerTokenResolver() {
    DefaultBearerTokenResolver delegate = new DefaultBearerTokenResolver();
    return request ->
        request.getRequestURI().startsWith(AUTH_PATH_PREFIX) ? null : delegate.resolve(request);
  }

  /** Hands security exceptions to the MVC exception handlers, which render Problem Details. */
  @Bean
  AuthenticationEntryPoint problemDetailsEntryPoint(
      @Qualifier("handlerExceptionResolver") HandlerExceptionResolver resolver) {
    return (request, response, exception) ->
        resolver.resolveException(request, response, null, exception);
  }

  @Bean
  AccessDeniedHandler problemDetailsAccessDeniedHandler(
      @Qualifier("handlerExceptionResolver") HandlerExceptionResolver resolver) {
    return (request, response, exception) ->
        resolver.resolveException(request, response, null, exception);
  }
}
