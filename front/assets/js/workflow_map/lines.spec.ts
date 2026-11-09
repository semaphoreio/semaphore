import { expect } from "chai";
import { describe, test } from "mocha";

import { Block, Job } from "./model";
import { BLOCK, BLOCK_HEAD_H, JOB_ROW_H, JOB_LINE_H, META_LINE_H, NAME_LINE_H, OPEN_BLOCK_W, blockSize, jobTop } from "./lines";

const job = (key: string, name: string, status = `passed`) => ({ key, id: null, name, status, startedAt: null, finishedAt: null, reused: false }) as Job;
const block = (name: string, jobs: Job[] = []) => ({ id: name, name, deps: [], jobs }) as Block;

const SHORT = `lint`;
const LONG = `integration tests against the staging database`;

describe(`block sizes on the map`, () => {
  test(`a collapsed block grows by one line when its name needs two`, () => {
    expect(blockSize(block(SHORT), false)).to.deep.equal(BLOCK);
    expect(blockSize(block(LONG), false)).to.deep.equal({ w: BLOCK.w, h: BLOCK.h + NAME_LINE_H });
  });

  test(`a collapsed block grows by one line when its job counts wrap`, () => {
    const mixed = [`failed`, `running`, `queued`, `stopped`, `passed`].map((s) => job(s, s, s));
    expect(blockSize(block(SHORT, mixed), false)).to.deep.equal({ w: BLOCK.w, h: BLOCK.h + META_LINE_H });
  });

  test(`an open block adds a line for a long name and for each long job name`, () => {
    expect(blockSize(block(SHORT, [job(`a`, SHORT)]), true)).to.deep.equal({ w: OPEN_BLOCK_W, h: BLOCK_HEAD_H + JOB_ROW_H + 8 });
    expect(blockSize(block(LONG, [job(`a`, SHORT), job(`b`, LONG)]), true)).to.deep.equal({
      w: OPEN_BLOCK_W,
      h: BLOCK_HEAD_H + NAME_LINE_H + JOB_ROW_H + JOB_ROW_H + JOB_LINE_H + 8,
    });
  });

  test(`each job row starts below the rows before it`, () => {
    const b = block(SHORT, [job(`a`, LONG), job(`b`, SHORT), job(`c`, SHORT)]);

    expect(jobTop(b, 0)).to.equal(BLOCK_HEAD_H);
    expect(jobTop(b, 1)).to.equal(BLOCK_HEAD_H + JOB_ROW_H + JOB_LINE_H);
    expect(jobTop(b, 2)).to.equal(BLOCK_HEAD_H + 2 * JOB_ROW_H + JOB_LINE_H);
  });
});
