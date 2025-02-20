import { expect } from "chai";
import { describe, test } from "mocha";
import { faker } from "@faker-js/faker";

import { JSONTypes } from "./json_types.fixture";
import { Report } from "./report";
import { Suite } from "./suite";


describe(`Report constructor`, () => {
  test(`should work with test report json`, () => {
    const json = JSONTypes.Fixture.Report();
    const report = Report.fromJSON(json);

    expect(report).to.be.instanceof(Report);
    expect(report).to.deep.contain({
      id: json.id,
      name: json.name,
      framework: json.framework,
      disabled: json.isDisabled,
    });
  });

  test(`should parse suites correctly`, () => {
    const suitesCount = faker.mersenne.rand(100, 1);
    const suites = [Array.from({ length: suitesCount })].map(() => JSONTypes.Fixture.Suite());
    const json = JSONTypes.Fixture.Report();

    expect(Report.fromJSON({ ...json, suites: [] }).suites).to.be.empty;

    const oneSuite = faker.helpers.arrayElement(suites);
    let report = Report.fromJSON({ ...json, suites: [oneSuite] });
    expect(report.suites).to.have.length(1);
    expect(report.suites[0]).to.be.instanceof(Suite);

    report = Report.fromJSON({ ...json, suites: suites });
    expect(report.suites).to.have.length(suites.length);
    report.suites.forEach((suite) => {
      expect(suite).to.be.instanceof(Suite);
    });
  });
});
