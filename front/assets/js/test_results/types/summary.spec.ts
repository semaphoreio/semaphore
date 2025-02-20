import { expect } from "chai";
import { describe, test } from "mocha";
import { JSONSummary } from "./json_types";
import { Summary } from "./summary";

describe(`Summary constructor`, () => {
  test(`should work with a summary json`, () => {
    const json: JSONSummary = {
      total: 14,
      passed: 2,
      skipped: 3,
      error: 4,
      failed: 5,
      duration: 12345
    };

    const summary = Summary.fromJSON(json);
    expect(summary).to.be.instanceof(Summary);
    expect(summary.total).to.eq(14);
    expect(summary.passed).to.eq(2);
    expect(summary.skipped).to.eq(3);
    expect(summary.failed).to.eq(9);
    expect(summary.duration).to.eq(12345);
  });
});
