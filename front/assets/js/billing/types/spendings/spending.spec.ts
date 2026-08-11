import { expect } from "chai";
import { describe, test } from "mocha";

import * as Formatter from "js/toolbox/formatter";

describe(`discountedTotal calculation`, () => {
  interface spec {
    usageTotal: string;
    discountAmount: string;
    output: string;
  }

  const discountedTotal = (usageTotal: string, discountAmount: string): string => {
    const usage = Formatter.parseMoney(usageTotal);
    const discountAmt = Formatter.parseMoney(discountAmount);
    return Formatter.toMoney(usage - discountAmt);
  };

  test(`should subtract discount from usage total`, () => {
    const specs = [
      { usageTotal: `$117.86`, discountAmount: `$5.89`, output: `$111.97` },
      { usageTotal: `$100.00`, discountAmount: `$0.00`, output: `$100.00` },
      { usageTotal: `$10,000.00`, discountAmount: `$500.00`, output: `$9,500.00` },
      { usageTotal: `$7.74`, discountAmount: `$2.249`, output: `$5.49` },
      { usageTotal: `$0.00`, discountAmount: `$0.00`, output: `$0.00` },
    ] as spec[];

    specs.forEach((spec) => {
      expect(
        discountedTotal(spec.usageTotal, spec.discountAmount),
        `${spec.usageTotal} - ${spec.discountAmount} should be ${spec.output}`
      ).to.eq(spec.output);
    });
  });
});
