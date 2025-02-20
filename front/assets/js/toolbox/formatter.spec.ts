import { expect } from "chai";
import { describe, test } from "mocha";

import * as Formatter from "./formatter";

describe(`Formatter.decimalThousands`, () => {
  interface spec {
    input: number;
    output: string;
  }

  test(`should format data properly`, () => {
    const specs = [
      { input: 0, output: `0` },
      { input: 1, output: `1` },
      { input: 10, output: `10` },
      { input: 100, output: `100` },
      { input: 1000, output: `1,000` },
      { input: 10000, output: `10,000` },
      { input: 100000, output: `100,000` },
      { input: 1000000, output: `1,000,000` },
      { input: 10000000, output: `10,000,000` },
      { input: 100000000, output: `100,000,000` },
      { input: 1000000000, output: `1,000,000,000` },
    ] as spec[];

    specs.forEach((spec) => {
      const result = Formatter.decimalThousands(spec.input);

      expect(result, `${spec.input} should format to ${spec.output}`).to.eq(spec.output);
    });
  });
});

describe(`Formatter.decimalThousandsWithPrecision`, () => {
  interface spec {
    input: number;
    output: string;
    precision: number;
  }

  test(`should format data properly`, () => {
    const specs = [
      { precision: 2, input: 0.00, output: `0.00` },
      { precision: 2, input: 1.123, output: `1.12` },
      { precision: 2, input: 10.43, output: `10.43` },
      { precision: 2, input: 100.2333, output: `100.23` },
      { precision: 2, input: 1000.5213, output: `1,000.52` },
      { precision: 2, input: 10000.3213, output: `10,000.32` },
      { precision: 2, input: 100000.4242, output: `100,000.42` },
      { precision: 2, input: 1000000.5555, output: `1,000,000.56` },
      { precision: 2, input: 10000000.1231, output: `10,000,000.12` },
      { precision: 2, input: 100000000.521, output: `100,000,000.52` },
      { precision: 2, input: 1000000000.01, output: `1,000,000,000.01` },
    ] as spec[];

    specs.forEach((spec) => {
      const result = Formatter.decimalThousandsWithPrecision(spec.input, spec.precision);

      expect(result, `${spec.input} should format to ${spec.output}`).to.eq(spec.output);
    });
  });
});


describe(`Formatter.stringToHexColor`, () => {
  interface spec {
    input: string;
    output: string;
  }
  test(`should format data properly`, () => {
    const specs = [
      { input: `foo`, output: `#c68c01ff` },
      { input: `bar`, output: `#137c01ff` },
      { input: `baz`, output: `#1b7c01ff` },
    ] as spec[];

    specs.forEach((spec) => {
      const result = Formatter.stringToHexColor(spec.input);

      expect(result, `${spec.input} should format to ${spec.output}`).to.eq(spec.output);
    });
  });
});


describe(`Formatter.humanize`, () => {
  interface spec {
    input: string;
    output: string;
  }
  test(`should format data properly`, () => {
    const specs = [
      { input: `foo_bar`, output: `Foo Bar` },
      { input: `fooBar`, output: `Foo Bar` },
      { input: `foo`, output: `Foo` },
      { input: `Foo`, output: `Foo` },
      { input: `foo bar`, output: `Foo Bar` },
      { input: `foo-bar`, output: `Foo Bar` },
    ] as spec[];

    specs.forEach((spec) => {
      const result = Formatter.humanize(spec.input);

      expect(result, `${spec.input} should format to ${spec.output}`).to.eq(spec.output);
    });
  });
});

describe(`Formatter.parseMoney`, () => {
  interface spec {
    input: string;
    output: number;
  }
  test(`should format data properly`, () => {
    const specs = [
      { input: `$ 23.00`, output: 23.00 },
      { input: `$ 0.00`, output: 0.00 },
      { input: `$ 11.23`, output: 11.23 },
      { input: `$ 123,000.00`, output: 123000 },
      { input: `$ 12,345.67`, output: 12345.67 },
      { input: `$ 0.01`, output: 0.01 },
    ] as spec[];

    specs.forEach((spec) => {
      const result = Formatter.parseMoney(spec.input);

      expect(result, `${spec.input} should format to ${spec.output}`).to.eq(spec.output);
    });
  });
});

describe(`Formatter.toMoney`, () => {
  interface spec {
    input: number;
    output: string;
  }
  test(`should format data properly`, () => {
    const specs = [
      { input: 23.00, output: `$23.00`, },
      { input: 0.00, output: `$0.00`, },
      { input: 11.23, output: `$11.23`, },
      { input: 123000, output: `$123,000.00`, },
      { input: 12345.67, output: `$12,345.67`, },
      { input: 0.01, output: `$0.01`, },
    ] as spec[];

    specs.forEach((spec) => {
      const result = Formatter.toMoney(spec.input);

      expect(result, `${spec.input} should format to ${spec.output}`).to.eq(spec.output);
    });
  });
});

describe(`Formatter.formatTestDuration`, () => {
  interface spec {
    input: number;
    output: string;
  }

  test(`should format data properly`, () => {
    const specs = [
      { input: 0, output: `0ms` },
      { input: 1, output: `1ms` },
      { input: 10, output: `10ms` },
      { input: 11.100000000002183, output: `11ms` },
      { input: 100, output: `0.10s` },
      { input: 1000, output: `1.00s` },
      { input: 10000, output: `10.00s` },
      { input: 100000, output: `1:40min` },
      { input: 1000000, output: `16:40min` },
      { input: 10000000, output: `166:40min` },
      { input: 100000000, output: `1666:40min` },
      { input: 1000000000, output: `16666:40min` },
    ] as spec[];

    specs.forEach((spec) => {
      const result = Formatter.formatTestDuration(spec.input);

      expect(result, `${spec.input} should format to ${spec.output}`).to.eq(spec.output);
    });
  });
});
