import type { FilterStore } from "../stores";
import type { Stateful } from "../util/stateful";
import { GetState, State } from "../util/stateful";
import type { JSONTestCase, JSONFailure } from "./json_types";

function parseState(state: string): State {
  switch (state) {
    case `passed`:
      return State.PASSED;
    case `failed`:
      return State.FAILED;
    case `error`:
      return State.FAILED;
    case `skipped`:
      return State.SKIPPED;
    case `disabled`:
      return State.SKIPPED;
    default:
      return State.PASSED;
  }
}

function parseFailure(json: JSONTestCase): Failure {
  let failure: Failure = new Failure({ message: ``, type: ``, body: `` } as Failure);

  if (json.failure) {
    failure = new Failure(json.failure as Failure);
  }

  if (json.error) {
    failure = new Failure(json.error as Failure);
  }

  return failure;
}

export class Failure {
  message: string;
  type: string;
  body: string;

  static fromJSON(json: JSONFailure): Failure {
    return {
      message: json.message,
      type: json.type,
      body: json.body,
    } as Failure;
  }

  constructor(failure: Failure) {
    this.message = failure.message;
    this.type = failure.type;
    this.body = failure.body;
  }


  isEmpty(): boolean {
    return this.message == `` && this.type == `` && this.body == ``;
  }
}

export class TestCase implements Stateful {
  id: string;
  fileName: string;
  className: string;
  packageName: string;
  name: string;
  duration: number;
  systemOut: string;
  systemErr: string;
  failure: Failure;
  state: State;

  static fromJSON(json: JSONTestCase): TestCase {
    return new TestCase({
      id: json.id,
      fileName: json.file,
      className: json.classname,
      packageName: json.package,
      name: json.name,
      duration: json.duration,
      state: parseState(json.state),
      systemOut: json.systemOut,
      systemErr: json.systemErr,
      failure: parseFailure(json),
    } as TestCase);
  }

  constructor(testCase: TestCase) {
    this.id = testCase.id;
    this.fileName = testCase.fileName;
    this.className = testCase.className;
    this.packageName = testCase.packageName;
    this.name = testCase.name;
    this.duration = testCase.duration;
    this.state = testCase.state;
    this.systemOut = testCase.systemOut;
    this.systemErr = testCase.systemErr;
    this.failure = testCase.failure;
    this.state = GetState(this);
  }

  matchesString(query: string): boolean {
    const nameMatches = this.name.toLowerCase().includes(query.toLowerCase());
    const fileNameMatches = this.fileName.toLowerCase().includes(query.toLowerCase());
    const classNameMatches = this.className.toLowerCase().includes(query.toLowerCase());
    const packageNameMatches = this.packageName.toLowerCase().includes(query.toLowerCase());
    const failureMatches = this.failure.message.toLowerCase().includes(query.toLowerCase());
    return nameMatches || failureMatches || fileNameMatches || classNameMatches || packageNameMatches;
  }


  matchesFilter(filterState: FilterStore.State): boolean {
    const contentMatches = this.matchesString(filterState.query);
    const stateMatches = filterState.excludedStates.includes(this.state);

    return contentMatches && !stateMatches;
  }
}
