import { expect } from "chai";
import { describe, test } from "mocha";

import { Formatter } from "./formatter";


describe(`Formatter.dailyRate`, () => {
  interface dailyRateSpec {
    total: number;
    days: number;
    expected: string;
  }

  test(`should work with test report json`, () => {
    const specs = [
      { total: 0, days: 0, expected: `N/A` },
      { total: 0, days: 30, expected: `N/A` },
      { total: 12, days: 3, expected: `4/day` },
      { total: 30, days: 30, expected: `1/day` },
      { total: 1, days: 30, expected: `< 1/month` },
      { total: 2, days: 30, expected: `2/month` },
      { total: 4, days: 30, expected: `4/month` },
      { total: 5, days: 30, expected: `1/week` },
      { total: 14, days: 30, expected: `3/week` },
      { total: 3, days: 7, expected: `3/week` },
      { total: 4, days: 7, expected: `4/week` },
      { total: 5, days: 7, expected: `1/day` },
      { total: 6, days: 7, expected: `1/day` },
      { total: 7, days: 7, expected: `1/day` },
      { total: 10, days: 7, expected: `1/day` },
      { total: 14, days: 7, expected: `2/day` },
      { total: 14, days: 1, expected: `14/day` },
      { total: 1000, days: 1, expected: `1000/day` },
    ] as dailyRateSpec[];

    specs.forEach((spec) => {
      expect(
        Formatter.dailyRate(spec.total, spec.days),
        `${spec.total} build / ${spec.days} days should format to ${spec.expected}`,
      ).to.eq(spec.expected);
    });
  });
});

describe(`Formatter.dateDiff`, () => {
  interface dateDiffSpec {
    start: Date;
    end: Date;
    expected: string;
  }

  test(`should work with test report json`, () => {
    const specs = [
      { start: new Date(0), end: new Date(), expected: `N/A` },
      { start: new Date(), end: new Date(0), expected: `N/A` },
      { start: new Date(`2022-01-01`), end: new Date(`2022-01-01`), expected: `a few seconds ago` },
      { start: new Date(`2022-01-01 00:00:00`), end: new Date(`2022-01-01 00:01:00`), expected: `a minute ago` },
      { start: new Date(`2022-01-01 00:00:00`), end: new Date(`2022-01-01 00:05:00`), expected: `5 minutes ago` },
      { start: new Date(`2022-01-01 00:00:00`), end: new Date(`2022-01-01 00:15:00`), expected: `15 minutes ago` },
      { start: new Date(`2022-01-01 00:00:00`), end: new Date(`2022-01-01 01:15:00`), expected: `an hour ago` },
      { start: new Date(`2022-01-01 00:00:00`), end: new Date(`2022-01-01 04:15:00`), expected: `4 hours ago` },
      { start: new Date(`2022-01-01`), end: new Date(`2022-01-02`), expected: `a day ago` },
      { start: new Date(`2022-01-01`), end: new Date(`2022-01-07`), expected: `6 days ago` },
      { start: new Date(`2022-01-01`), end: new Date(`2022-01-08`), expected: `7 days ago` },
      { start: new Date(`2022-01-01`), end: new Date(`2022-01-09`), expected: `8 days ago` },
      { start: new Date(`2022-01-01`), end: new Date(`2022-01-31`), expected: `a month ago` },
      { start: new Date(`2022-01-01`), end: new Date(`2022-03-31`), expected: `3 months ago` },
    ] as dateDiffSpec[];

    specs.forEach((spec) => {
      expect(
        Formatter.dateDiff(spec.start, spec.end),
        `${spec.start.toDateString()} => ${spec.end.toDateString()} should format to ${spec.expected}`,
      ).to.eq(spec.expected);
    });
  });
});

describe(`Formatter.duration`, () => {
  interface durationSpec {
    seconds: number;
    expected: string;
  }

  test(`should work with test report json`, () => {
    const minute = 1 * 60;
    const hour = minute * 60;
    const day = hour * 24;

    const specs = [
      { seconds: 0, expected: `N/A` },
      { seconds: 1, expected: `1s` },
      { seconds: 15, expected: `15s` },
      { seconds: 30, expected: `30s` },
      { seconds: 90, expected: `1m 30s` },
      { seconds: 119, expected: `1m 59s` },
      { seconds: 59 * minute + 59, expected: `59m 59s` },
      { seconds: 60 * minute, expected: `1h 0m 0s` },
      { seconds: 60 * minute + 1, expected: `1h 0m 1s` },
      { seconds: 12 * hour, expected: `12h 0m 0s` },
      { seconds: 13 * hour, expected: `13h 0m 0s` },
      { seconds: 23 * hour + 59 * minute + 59, expected: `23h 59m 59s` },
      { seconds: 24 * hour, expected: `1d 0h 0m 0s` },
      { seconds: 1 * day + 1 , expected: `1d 0h 0m 1s` },
      { seconds: 1 * day + 2 * hour + 3 * minute + 4 , expected: `1d 2h 3m 4s` },
    ] as durationSpec[];

    specs.forEach((spec) => {
      expect(
        Formatter.duration(spec.seconds),
        `${spec.seconds} seconds should format to ${spec.expected}`,
      ).to.eq(spec.expected);
    });
  });
});
