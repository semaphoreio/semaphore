import * as types from "./index";

export class MetricsDateRange {
  ranges: MetricDateRange[];

  static fromJSON(json: types.JSONInterface.AvailableDateRanges): MetricsDateRange {
    const metricsDateRange = new MetricsDateRange();
    metricsDateRange.ranges = json.available_dates.map((range: types.JSONInterface.MetricDateRange) =>
      MetricDateRange.fromJSON(range)
    );
    return metricsDateRange;
  }
}

export class MetricDateRange {
  label: string;
  from: string;
  to: string;

  static fromJSON(json: types.JSONInterface.MetricDateRange): MetricDateRange {
    const metricDateRange = new MetricDateRange();
    metricDateRange.label = json.label;
    metricDateRange.from = json.from;
    metricDateRange.to = json.to;
    return metricDateRange;
  }
}
