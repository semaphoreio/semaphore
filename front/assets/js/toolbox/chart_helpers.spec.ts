import { expect } from "chai";
import { describe, test } from "mocha";

import * as ChartHelpers from "./chart_helpers";

describe(`ChartHelpers.CalculateOptimalRange`, () => {
  interface spec {
    input: number[];
    output: number[];
  }

  test(`should calculate optimal ranges for values`, () => {
    const specs = [
      { input: [], output: [0, 1, 2, 3, 4, 5] },
      { input: [20], output: [0, 4, 8, 12, 16, 20] },
      { input: [0, 1, 0, 1, 0, 1, 0, 1], output: [0, 1, 2, 3, 4, 5] },
      { input: [0, 15, 20, 50, 120, 50, 60, 11], output: [0, 40, 80, 120, 160, 200] },
    ] as spec[];

    specs.forEach((spec) => {
      const result = ChartHelpers.CalculateOptimalRange(spec.input);

      expect(result, `ChartHelpers.CalculateOptimalRange(${JSON.stringify(spec.input)})`).to.deep.equal(spec.output);
    });
  });
});
