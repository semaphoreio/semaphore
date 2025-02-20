import { expect } from "chai";
import { describe, test } from "mocha";
import { TestCase } from "./test_case";
import { State } from "../util/stateful";
import { JSONTypes } from "./json_types.fixture";

describe(`TestCase constructor`, () => {
  test(`should work with a test report json`, () => {
    const json = JSONTypes.Fixture.TestCase();

    const testCase = TestCase.fromJSON(json);
    expect(testCase).to.be.instanceof(TestCase);
    expect(testCase).to.deep.contain({
      id: json.id,
      name: json.name,
      fileName: json.file,
      className: json.classname,
      packageName: json.package,
      duration: json.duration,
      systemOut: json.systemOut,
      systemErr: json.systemErr,
    });
  });

  test(`should parse state correctly`, () => {
    const json = JSONTypes.Fixture.TestCase();
    expect(TestCase.fromJSON({ ...json, state: `passed` }).state).to.eq(State.PASSED, `should parse passed state`);
    expect(TestCase.fromJSON({ ...json, state: `failed` }).state).to.eq(State.FAILED, `should parse failed state`);
    expect(TestCase.fromJSON({ ...json, state: `error` }).state).to.eq(State.FAILED, `should parse error state`);
    expect(TestCase.fromJSON({ ...json, state: `skipped` }).state).to.eq(State.SKIPPED, `should parse skipped state`);
    expect(TestCase.fromJSON({ ...json, state: `disabled` }).state).to.eq(State.SKIPPED, `should parse disabled state`);
    expect(TestCase.fromJSON({ ...json, state: `unknown` }).state).to.eq(State.PASSED, `should parse unknown state`);
  });

  test(`should parse failed test case details`, () => {
    const json = JSONTypes.Fixture.TestCase();
    expect(TestCase.fromJSON({ ...json, failure: undefined, error: undefined }).failure).to.deep.contain({
      message: ``,
      type: ``,
      body: ``,
    }, `should have a valid zero state`);

    const failure = JSONTypes.Fixture.Failure();
    expect(TestCase.fromJSON({ ...json, failure: failure, error: undefined }).failure).to.deep.contain({
      message: failure.message,
      type: failure.type,
      body: failure.body,
    }, `should work with failures`);

    const error = JSONTypes.Fixture.Failure();
    expect(TestCase.fromJSON({ ...json, failure: undefined, error: error }).failure).to.deep.contain({
      message: error.message,
      type: error.type,
      body: error.body,
    }, `should work with errors`);
  });
});
