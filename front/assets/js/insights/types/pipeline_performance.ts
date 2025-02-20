import * as types from './index';

export class DynamicMetrics {
  metrics: DynamicMetric[];

  constructor() {
    this.metrics = [];
  }

  static fromJSON(json: types.JSONInterface.PipelinePerformance): DynamicMetrics {
    const dynamicMetrics = new DynamicMetrics();
    dynamicMetrics.metrics = json.all
      .map((value) => {
        return DynamicMetric.fromJSON(value);
      })
      .filter(m => !m.isEmpty());

    return dynamicMetrics;
  }
}


export class DynamicMetric implements types.Chart.PerformanceMetric {
  fromDate: Date;
  count: number;
  _mean: number;
  _min: number;
  _max: number;
  _stdDev: number;
  _p50: number;
  _p95: number;

  static fromJSON(json: types.JSONInterface.PerformanceMetric): DynamicMetric {
    const metric = new DynamicMetric();
    metric.fromDate = new Date(json.from_date);
    metric.count = json.count;
    metric._mean = json.mean;
    metric._min = json.min;
    metric._max = json.max;
    metric._stdDev = json.std_dev;
    metric._p50 = json.p50;
    metric._p95 = json.p95;

    return metric;
  }

  isEmpty(): boolean {
    return this.count == 0;
  }

  get value(): number {
    return this._mean;
  }

  get date() {
    return this.fromDate;
  }

  get min(): number {
    return this._min;
  }
  get max(): number {
    return this._max;
  }
  get p50(): number {
    return this._p50;
  }
  get p95(): number {
    return this._p95;
  }
  get mean(): number {
    return this._mean;
  }
  get stdDev(): number {
    return this._stdDev;
  }
}

export class Metrics {
  all: Metric[];
  passed: Metric[];
  failed: Metric[];

  constructor() {
    this.all = [];
    this.passed = [];
    this.failed = [];
  }

  static fromJSON(json: types.JSONInterface.PipelinePerformance): Metrics {
    const metrics = new Metrics();
    metrics.passed = json.passed
      .map((value) => {
        const metric = Metric.fromJSON(value);
        metric.passedCount = metric.count;
        return metric;
      })
      .filter(m => !m.isEmpty());

    metrics.failed = json.failed
      .map((value) => {
        const metric = Metric.fromJSON(value);
        metric.failedCount = metric.count;
        return metric;
      })
      .filter(m => !m.isEmpty());

    metrics.all = json.all
      .map((value) => {
        const metric = Metric.fromJSON(value);
        const failedMetric = metrics.failed.find((failedMetric) => {
          return failedMetric.fromDate.getTime() == metric.fromDate.getTime() && failedMetric.toDate.getTime() == metric.toDate.getTime();
        });

        if(failedMetric) {
          metric.failedCount = failedMetric.count;
        }
        const passedMetric = metrics.passed.find((passedMetric) => {
          return passedMetric.fromDate.getTime() == metric.fromDate.getTime() && passedMetric.toDate.getTime() == metric.toDate.getTime();
        });

        if(passedMetric) {
          metric.passedCount = passedMetric.count;
        }

        return metric;
      })
      .filter(m => !m.isEmpty());
    return metrics;
  }
}

export class Summary {
  fromDate: Date;
  toDate: Date;
  all: Metric;
  passed: Metric;
  failed: Metric;

  static fromJSON(json: types.JSONInterface.PipelinePerformance): Summary {
    const summary = new Summary();
    summary.all = Metric.fromJSON(json.all[0]);
    summary.passed = Metric.fromJSON(json.passed[0]);
    summary.failed = Metric.fromJSON(json.failed[0]);
    summary.fromDate = summary.all.fromDate;
    summary.toDate = summary.all.fromDate;
    return summary;
  }
}

export class Metric implements types.Chart.MetricWithStdDev {
  fromDate: Date;
  toDate: Date;

  count: number;
  passedCount: number;
  failedCount: number;
  mean: number;
  min: number;
  max: number;
  stdDev: number;
  p50: number;
  p95: number;

  static fromJSON(json: types.JSONInterface.PerformanceMetric): Metric {
    const metric = new Metric();
    metric.fromDate = new Date(json.from_date);
    metric.toDate = new Date(json.to_date);
    metric.count = json.count;
    metric.passedCount = 0;
    metric.failedCount = 0;
    metric.mean = json.mean;
    metric.min = json.min;
    metric.max = json.max;
    metric.stdDev = json.std_dev;
    metric.p50 = json.p50;
    metric.p95 = json.p95;
    return metric;
  }

  isEmpty(): boolean {
    return this.count == 0;
  }

  get value(): number {
    return this.mean;
  }

  get date() {
    return this.fromDate;
  }
}
