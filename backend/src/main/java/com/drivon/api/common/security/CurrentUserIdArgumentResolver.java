package com.drivon.api.common.security;

import com.drivon.api.common.error.DrivonException;
import com.drivon.api.common.error.ErrorCode;
import java.util.UUID;
import org.springframework.core.MethodParameter;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.bind.support.WebDataBinderFactory;
import org.springframework.web.context.request.NativeWebRequest;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.method.support.ModelAndViewContainer;

/** Resolves {@link CurrentUserId} parameters from the JWT subject in the security context. */
public final class CurrentUserIdArgumentResolver implements HandlerMethodArgumentResolver {

  @Override
  public boolean supportsParameter(MethodParameter parameter) {
    return parameter.hasParameterAnnotation(CurrentUserId.class)
        && UUID.class.equals(parameter.getParameterType());
  }

  @Override
  public UUID resolveArgument(
      MethodParameter parameter,
      ModelAndViewContainer mavContainer,
      NativeWebRequest webRequest,
      WebDataBinderFactory binderFactory) {
    Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
    if (authentication instanceof JwtAuthenticationToken jwt) {
      try {
        return UUID.fromString(jwt.getToken().getSubject());
      } catch (IllegalArgumentException | NullPointerException e) {
        throw new DrivonException(ErrorCode.UNAUTHENTICATED);
      }
    }
    throw new DrivonException(ErrorCode.UNAUTHENTICATED);
  }
}
