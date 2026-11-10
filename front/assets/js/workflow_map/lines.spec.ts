import { expect } from "chai";
import { describe, test } from "mocha";

import { Block, Job } from "./model";
import { BLOCK, BLOCK_HEAD_H, JOB_ROW_H, OPEN_BLOCK_W, blockSize, jobTop } from "./lines";

const job = (key: string, name: string) => ({ key, id: null, name, status: `passed`, startedAt: null, finishedAt: null, reused: false }) as Job;
const block = (name: string, jobs: Job[] = []) => ({ id: name, name, deps: [], jobs }) as Block;

const LONG = `integration tests against the staging database with a name far wider than any block`;

describe(`block sizes on the map`, () => {
  test(`a collapsed block has one size whatever its name`, () => {
    expect(blockSize(block(`lint`), false)).to.deep.equal(BLOCK);
    expect(blockSize(block(LONG), false)).to.deep.equal(BLOCK);
  });

  test(`an open block is one row per job, whatever the names`, () => {
    expect(blockSize(block(`lint`, [job(`a`, `lint`)]), true)).to.deep.equal({ w: OPEN_BLOCK_W, h: BLOCK_HEAD_H + JOB_ROW_H + 8 });
    expect(blockSize(block(LONG, [job(`a`, `lint`), job(`b`, LONG)]), true)).to.deep.equal({ w: OPEN_BLOCK_W, h: BLOCK_HEAD_H + 2 * JOB_ROW_H + 8 });
  });

  test(`each job row starts one row below the one before it`, () => {
    expect([0, 1, 2].map(jobTop)).to.deep.equal([BLOCK_HEAD_H, BLOCK_HEAD_H + JOB_ROW_H, BLOCK_HEAD_H + 2 * JOB_ROW_H]);
  });
});
