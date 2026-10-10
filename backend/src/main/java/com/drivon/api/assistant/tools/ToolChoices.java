package com.drivon.api.assistant.tools;

/** Fixed choices the model picks from in tool arguments. */
final class ToolChoices {

  private ToolChoices() {}

  /** Named periods for spending totals. */
  enum Period {
    THIS_MONTH,
    LAST_MONTH,
    THIS_YEAR,
    LAST_YEAR,
    LAST_12_MONTHS,
    ALL_TIME
  }

  /** What a monthly trend follows. */
  enum TrendMetric {
    TOTAL,
    FUEL,
    MAINTENANCE,
    OTHER,
    DISTANCE,
    COST_PER_KM
  }

  /** What vehicles are compared by. */
  enum ComparisonMetric {
    COST_PER_KM,
    TOTAL_COST,
    DISTANCE,
    KM_PER_LITRE
  }
}
