package com.drivon.api.user;

import java.util.Locale;

/** Email normalization shared by registration and login. */
public final class Emails {

  private Emails() {}

  /** Trims and lower-cases an address so lookups and uniqueness are case-insensitive. */
  public static String normalize(String email) {
    return email.strip().toLowerCase(Locale.ROOT);
  }
}
