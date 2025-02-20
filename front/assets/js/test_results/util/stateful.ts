import { Report } from "../types/report";
import { Suite } from "../types/suite";
import { Summary } from "../types/summary";
import { TestCase } from "../types/test_case";

export enum State {
  EMPTY = 0,
  SKIPPED,
  PASSED,
  FAILED,
}

const getSummaryState = (summary: Summary) => {
  if(summary.failed > 0) {
    return State.FAILED;
  } else if (summary.passed > 0) {
    return State.PASSED;
  } else if (summary.skipped > 0) {
    return State.SKIPPED;
  } else {
    return State.EMPTY;
  }
};

const getSuiteState = (suite: Suite): State => {
  return getSummaryState(suite.summary);
};

const getReportState = (report: Report): State => {
  return getSummaryState(report.summary);
};

const getTestState = (entity: TestCase): State => {
  return entity.state;
};

export const GetState = (s: Stateful): State => {
  switch (s.constructor) {
    case TestCase:
      return getTestState(s as unknown as TestCase);
    case Suite:
      return getSuiteState(s as unknown as Suite);
    case Report:
      return getReportState(s as unknown as Report);
    case Summary:
      return getSummaryState(s as unknown as Summary);
    default:
      return State.EMPTY;
  }
};

export interface Stateful {
  state: State;
}
