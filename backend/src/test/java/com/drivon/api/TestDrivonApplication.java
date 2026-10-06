package com.drivon.api;

import org.springframework.boot.SpringApplication;

/**
 * Starts the API locally against a throwaway Testcontainers Postgres (no Docker Compose needed).
 */
public class TestDrivonApplication {

  public static void main(String[] args) {
    SpringApplication.from(DrivonApplication::main)
        .with(TestcontainersConfiguration.class)
        .run(args);
  }
}
