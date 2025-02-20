import * as types from "./index";

export class Summary {
  fromDate: Date;
  toDate: Date;
  allCount: number;
  passedCount: number;
  failedCount: number;

  static fromJSON(json: types.JSONInterface.PipelineReliability): Summary {
    const summary = new Summary();
    summary.fromDate = new Date(json.metrics[0].from_date);
    summary.toDate = new Date(json.metrics[0].to_date);
    summary.allCount = json.metrics[0].all_count;
    summary.passedCount = json.metrics[0].passed_count;
    summary.failedCount = json.metrics[0].failed_count;
    return summary;
  }

  get passRate(): number {
    return Math.round((this.passedCount / this.allCount) * 100);
  }
}

export class Metrics {
  metrics: Metric[];
  constructor() {
    this.metrics = [];
  }

  static fromJSON(json: types.JSONInterface.PipelineReliability): Metrics {
    const metrics = new Metrics();
    metrics.metrics = json.metrics.map(Metric.fromJSON);
    return metrics;
  }
}

export class Metric implements types.Chart.Metric {
  fromDate: Date;
  toDate: Date;
  allCount: number;
  passedCount: number;
  failedCount: number;
  passRate: number;

  static fromJSON(json: types.JSONInterface.ReliabilityMetric): Metric {
    const metric = new Metric();
    metric.fromDate = new Date(json.from_date);
    metric.toDate = new Date(json.to_date);
    metric.allCount = json.all_count;
    metric.passedCount = json.passed_count;
    metric.failedCount = json.failed_count;
    metric.passRate = Math.round((metric.passedCount / metric.allCount) * 100);
    if (metric.allCount == 0) {
      metric.passRate = 0;
    }
    return metric;
  }

  get value(): number {
    return this.passRate;
  }

  get date(): Date {
    return this.fromDate;
  }

  isEmpty(): boolean {
    return this.allCount === 0;
  }
}
