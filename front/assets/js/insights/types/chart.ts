export interface Metric {
  get value(): number;
  get date(): Date;
  isEmpty(): boolean;
}

export interface MetricWithStdDev extends Metric {
  get stdDev(): number;
}

export interface PerformanceMetric extends MetricWithStdDev {
  get min(): number;
  get max(): number;
  get p50(): number; //median
  get p95(): number;
  get mean(): number; //same as value, avg;
}