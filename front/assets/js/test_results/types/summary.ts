import { JSONSummary } from "./json_types";
import { GetState, State, Stateful } from "../util/stateful";

export class Summary implements Stateful {
  total: number;
  passed: number;
  skipped: number;
  failed: number;
  duration: number;
  state: State;

  static fromJSON(json: JSONSummary): Summary {
    return new Summary({
      total: json.total,
      passed: json.passed,
      skipped: json.skipped,
      failed: json.failed + json.error,
      duration: json.duration,
    } as Summary);
  }

  static empty(): Summary {
    return new Summary({
      total: 0,
      passed: 0,
      skipped: 0,
      failed: 0,
      duration: 0,
    } as Summary);
  }

  constructor(summary: Summary) {
    this.total = summary.total;
    this.passed = summary.passed;
    this.skipped = summary.skipped;
    this.failed = summary.failed;
    this.duration = summary.duration;
    this.state = GetState(this);
  }

  sub(summary: Summary) {
    return new Summary({
      total: this.total - summary.total,
      passed: this.passed - summary.passed,
      skipped: this.skipped - summary.skipped,
      failed: this.failed - summary.failed,
      duration: this.duration - summary.duration,
    } as Summary);
  }

  add(summary: Summary) {
    return new Summary({
      total: this.total + summary.total,
      passed: this.passed + summary.passed,
      skipped: this.skipped + summary.skipped,
      failed: this.failed + summary.failed,
      duration: this.duration + summary.duration,
    } as Summary);
  }

  formattedResults(): string {
    if(this.total == 0) {
      return `No tests executed`;
    }

    const results: string[] = [];
    if (this.passed) {
      results.push(`${this.passed} passed`);
    }
    if (this.failed) {
      results.push(`${this.failed} failed`);
    }
    if (this.skipped) {
      results.push(`${this.skipped} skipped`);
    }

    return results.join(`, `);
  }
}
