import { expect } from "chai";
import { describe, test } from "mocha";

import { dependencyTiers } from "./tiers";
import { Block } from "../types";

const block = (name: string, deps: string[]): Block => ({
  name,
  result: `passed`,
  reused_from: null,
  deps,
  jobs: [],
});

const tierNames = (blocks: Block[]): string[][] =>
  dependencyTiers(blocks).map((tier) => tier.map((entry) => entry.name));

describe(`dependencyTiers`, () => {
  test(`returns no tiers for an empty block list`, () => {
    expect(dependencyTiers([])).to.deep.eq([]);
  });

  test(`places every independent block in the first tier`, () => {
    const blocks = [block(`Lint`, []), block(`Setup`, [])];

    expect(tierNames(blocks)).to.deep.eq([[`Lint`, `Setup`]]);
  });

  test(`groups parallel blocks that share a dependency into one tier`, () => {
    const blocks = [
      block(`Setup`, []),
      block(`Unit tests`, [`Setup`]),
      block(`Integration tests`, [`Setup`]),
      block(`E2E tests`, [`Setup`]),
      block(`Packaging`, [`Unit tests`, `Integration tests`, `E2E tests`]),
    ];

    expect(tierNames(blocks)).to.deep.eq([
      [`Setup`],
      [`Unit tests`, `Integration tests`, `E2E tests`],
      [`Packaging`],
    ]);
  });

  test(`preserves the given order inside a tier`, () => {
    const blocks = [
      block(`Setup`, []),
      block(`E2E tests`, [`Setup`]),
      block(`Unit tests`, [`Setup`]),
    ];

    expect(tierNames(blocks)).to.deep.eq([[`Setup`], [`E2E tests`, `Unit tests`]]);
  });

  test(`ignores dependencies on blocks that are not part of the list`, () => {
    const blocks = [block(`Packaging`, [`Setup`])];

    expect(tierNames(blocks)).to.deep.eq([[`Packaging`]]);
  });

  test(`keeps cyclic blocks in a final tier instead of dropping them`, () => {
    const blocks = [
      block(`Setup`, []),
      block(`First`, [`Second`]),
      block(`Second`, [`First`]),
    ];

    expect(tierNames(blocks)).to.deep.eq([[`Setup`], [`First`, `Second`]]);
  });
});
