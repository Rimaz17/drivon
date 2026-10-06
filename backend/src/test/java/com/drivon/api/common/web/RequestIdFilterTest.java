package com.drivon.api.common.web;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;
import org.slf4j.MDC;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

class RequestIdFilterTest {

  private final RequestIdFilter filter = new RequestIdFilter();

  @Test
  void generatesRequestIdWhenHeaderIsMissing() throws Exception {
    MockHttpServletResponse response = run(new MockHttpServletRequest(), new AtomicReference<>());

    assertThat(response.getHeader(RequestIdFilter.HEADER)).matches("[0-9a-f-]{36}");
  }

  @Test
  void reusesWellFormedIncomingRequestId() throws Exception {
    MockHttpServletRequest request = new MockHttpServletRequest();
    request.addHeader(RequestIdFilter.HEADER, "abc-123-def-456");

    MockHttpServletResponse response = run(request, new AtomicReference<>());

    assertThat(response.getHeader(RequestIdFilter.HEADER)).isEqualTo("abc-123-def-456");
  }

  @Test
  void replacesMalformedIncomingRequestId() throws Exception {
    MockHttpServletRequest request = new MockHttpServletRequest();
    request.addHeader(RequestIdFilter.HEADER, "bad id\nwith newline");

    MockHttpServletResponse response = run(request, new AtomicReference<>());

    assertThat(response.getHeader(RequestIdFilter.HEADER))
        .isNotEqualTo("bad id\nwith newline")
        .matches("[0-9a-f-]{36}");
  }

  @Test
  void exposesRequestIdToLogsDuringRequestAndClearsItAfterwards() throws Exception {
    AtomicReference<String> seenInChain = new AtomicReference<>();

    MockHttpServletResponse response = run(new MockHttpServletRequest(), seenInChain);

    assertThat(seenInChain.get()).isEqualTo(response.getHeader(RequestIdFilter.HEADER));
    assertThat(MDC.get(RequestIdFilter.MDC_KEY)).isNull();
  }

  private MockHttpServletResponse run(
      MockHttpServletRequest request, AtomicReference<String> mdcInChain) throws Exception {
    MockHttpServletResponse response = new MockHttpServletResponse();
    MockFilterChain chain =
        new MockFilterChain() {
          @Override
          public void doFilter(
              jakarta.servlet.ServletRequest req, jakarta.servlet.ServletResponse res) {
            mdcInChain.set(MDC.get(RequestIdFilter.MDC_KEY));
          }
        };
    filter.doFilter(request, response, chain);
    return response;
  }
}
