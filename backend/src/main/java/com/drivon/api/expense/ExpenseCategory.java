package com.drivon.api.expense;

/**
 * Spending categories from the product overview. In spending totals, fill-ups count as {@link
 * #FUEL} and services as {@link #MAINTENANCE}, alongside expenses logged in those categories.
 */
public enum ExpenseCategory {
  FUEL,
  MAINTENANCE,
  REPAIRS,
  INSURANCE,
  PARKING,
  TOLLS,
  WASHING,
  OTHER
}
