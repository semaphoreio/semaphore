import { expect } from "chai";
import { describe, test } from "mocha";
import { faker } from "@faker-js/faker";
import { JSONTypes } from "./json_types.fixture";
import { Suite } from "./suite";
import { TestCase } from "./test_case";


describe(`Suite constructor`, () => {
  test(`should work with test suite json`, () => {
    const json = JSONTypes.Fixture.Suite();

    const suite = Suite.fromJSON(json);

    expect(suite).to.be.instanceof(Suite);
    expect(suite).to.deep.contain({
      id: json.id,
      name: json.name,
      packageName: json.package,
      skipped: json.isDisabled || json.isSkipped,
      timestamp: new Date(json.timestamp),
    });
  });

  test(`should parse tests correctly`, () => {
    const testsCount = faker.mersenne.rand(100, 1);
    const tests = [Array.from({ length: testsCount })].map(() => JSONTypes.Fixture.TestCase());
    const json = JSONTypes.Fixture.Suite();

    expect(Suite.fromJSON({ ...json, tests: [] }).tests).to.be.empty;

    const oneTest = faker.helpers.arrayElement(tests);
    let suite = Suite.fromJSON({ ...json, tests: [oneTest] });
    expect(suite.tests).to.have.length(1);
    expect(suite.tests[0]).to.be.instanceof(TestCase);

    suite = Suite.fromJSON({ ...json, tests: tests });
    expect(suite.tests).to.have.length(tests.length);
    suite.tests.forEach((test) => {
      expect(test).to.be.instanceof(TestCase);
    });
  });

  test(`should parse summary correctly`, () => {
    const summary = JSONTypes.Fixture.Summary();
    const suite = Suite.fromJSON(JSONTypes.Fixture.Suite({ summary: summary }));
    expect(suite.summary).to.deep.contain({
      total: summary.total,
      passed: summary.passed,
      failed: summary.error + summary.failed,
      skipped: summary.skipped,
      duration: summary.duration,
    });
  });
});
