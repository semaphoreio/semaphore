import _ from "lodash";
import type { FilterStore } from "../stores";
import type { JSONReport } from "./json_types";
import type { State, Stateful } from "../util/stateful";
import { GetState } from "../util/stateful";
import { Suite } from "./suite";
import { Summary } from "./summary";

export class Report implements Stateful{
  id: string;
  name: string;
  framework: string;
  disabled: boolean;
  suites: Suite[];
  summary: Summary;
  state: State;

  static fromJSON(json: JSONReport): Report {
    return new Report({
      id: json.id,
      name: json.name,
      framework: json.framework,
      disabled: json.isDisabled,
      suites: json.suites.map(Suite.fromJSON),
      summary: Summary.fromJSON(json.summary),
    } as Report);
  }

  constructor(report: Report) {
    this.id = report.id;
    this.name = ensureName(report);
    this.framework = report.framework;
    this.disabled = report.disabled;
    this.suites = report.suites;
    this.summary = report.summary;
    this.state = GetState(this);
  }

  isEmpty() {
    return this.suites.length === 0 || this.summary.total == 0;
  }

  applyFilter(filterState: FilterStore.State): Report {
    this.suites = this.suites.filter(suite => suite.matchesFilter(filterState));

    return this;
  }

  syncSummary() {
    this.summary = new Summary({
      duration: this.suites.reduce((duration, suite) => duration + suite.summary.duration, 0),
      total: this.suites.reduce((total, suite) => total + suite.summary.total, 0),
      failed: this.suites.reduce((failed, suite) => failed + suite.summary.failed, 0),
      passed: this.suites.reduce((passed, suite) => passed + suite.summary.passed, 0),
      skipped: this.suites.reduce((skipped, suite) => skipped + suite.summary.skipped, 0),
      state: GetState(this),
    } as Summary);
  }
}

const ensureName = ({ name, framework }: Report) =>{
  framework = _.isEmpty(framework) ? `test` : framework;
  switch (name) {
    case `Generic Suite`:
      return `Test Report`;
    case ``:
      return `${_.capitalize(framework)} Suite`;
    default:
      return name;
  }
};
