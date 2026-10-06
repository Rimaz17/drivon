package com.drivon.api;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.security.autoconfigure.UserDetailsServiceAutoConfiguration;

// Authentication is token-based; the default in-memory user (and its logged password) is unwanted.
@SpringBootApplication(exclude = UserDetailsServiceAutoConfiguration.class)
public class DrivonApplication {

  public static void main(String[] args) {
    SpringApplication.run(DrivonApplication.class, args);
  }
}
