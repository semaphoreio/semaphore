import moment from "moment";
import type * as types from "./index";
export class Metrics {
  metrics: Metric[];

  constructor() {
    this.metrics = [];
  }

  static fromJSON(json: types.JSONInterface.PipelineFrequency): Metrics {
    const metrics = new Metrics();
    metrics.metrics = json.metrics.map(Metric.fromJSON);
    return metrics;
  }
}

export class Summary {
  fromDate: Date;
  toDate: Date;
  count: number;

  static fromJSON(json: types.JSONInterface.PipelineFrequency): Summary {
    const summary = new Summary();
    summary.fromDate = new Date(json.metrics[0].from_date);
    summary.toDate = new Date(json.metrics[0].to_date);
    summary.count = json.metrics[0].count;
    return summary;
  }

  get daysDiff(): number {
    const days = moment(this.toDate).diff(this.fromDate, `day`);
    return days;
  }
}

export class Metric implements types.Chart.Metric {
  fromDate: Date;
  toDate: Date;
  count: number;

  static fromJSON(json: types.JSONInterface.FrequencyMetric): Metric {
    const metric = new Metric();
    metric.fromDate = new Date(json.from_date);
    metric.toDate = new Date(json.to_date);
    metric.count = json.count;
    return metric;
  }

  get value() {
    return this.count;
  }

  get date() {
    return this.fromDate;
  }

  isEmpty(): boolean {
    return this.count === 0;
  }
}
