package com.drivon.api.analytics;

import com.drivon.api.expense.ExpenseCategory;

/**
 * The three parts of a vehicle's running cost in the product overview: fuel, maintenance and
 * everything else.
 */
public enum CostGroup {
  /** Fill-ups and expenses logged as fuel. */
  FUEL,
  /** Services, and expenses logged as maintenance or repairs. */
  MAINTENANCE,
  /** Insurance, parking, tolls, washing and other expenses. */
  OTHER;

  static CostGroup of(ExpenseCategory category) {
    return switch (category) {
      case FUEL -> FUEL;
      case MAINTENANCE, REPAIRS -> MAINTENANCE;
      case INSURANCE, PARKING, TOLLS, WASHING, OTHER -> OTHER;
    };
  }
}
