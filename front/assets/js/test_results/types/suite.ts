import { JSONSuite } from "./json_types";
import { TestCase } from "./test_case";
import { Summary } from "./summary";
import { GetState, State, Stateful } from "../util/stateful";
import { FilterStore } from "../stores";

export class Suite implements Stateful {
  id: string;
  name: string;
  skipped: boolean;
  timestamp: Date;
  packageName: string;
  tests: TestCase[];
  summary: Summary;
  state: State;

  static fromJSON(json: JSONSuite): Suite {
    return new Suite({
      id: json.id,
      name: json.name,
      skipped: json.isDisabled || json.isSkipped,
      packageName: json.package,
      timestamp: new Date(json.timestamp),
      tests: json.tests.map(TestCase.fromJSON),
      summary: Summary.fromJSON(json.summary),
      state: State.EMPTY,
    } as Suite);
  }

  constructor(suite: Suite) {
    this.id = suite.id;
    this.name = suite.name;
    this.skipped = suite.skipped;
    this.timestamp = suite.timestamp;
    this.packageName = suite.packageName;
    this.tests = suite.tests;
    this.summary = suite.summary;
    this.state = GetState(this);
  }

  applyFilter(filterState: FilterStore.State): Suite {
    this.tests = this.tests.filter(test => test.matchesFilter(filterState));

    return this;
  }

  matchesFilter(filterState: FilterStore.State): boolean {
    const nameMatches = this.name.toLowerCase().includes(filterState.query.toLowerCase());
    const packageName = this.packageName.toLowerCase().includes(filterState.query.toLowerCase());
    const testMatches = this.tests.some(predicate => predicate.matchesFilter(filterState));
    const testsLength = this.tests.filter(predicate => predicate.matchesFilter(filterState)).length;

    return (nameMatches || packageName || testMatches) && testsLength > 0;
  }

  syncSummary() {
    this.summary = new Summary({
      duration: this.summary.duration,
      total: this.tests.length,
      failed: this.tests.filter(test => test.state === State.FAILED).length,
      passed: this.tests.filter(test => test.state === State.PASSED).length,
      skipped: this.tests.filter(test => test.state === State.SKIPPED).length,
      state: GetState(this),
    } as Summary);
  }
}
