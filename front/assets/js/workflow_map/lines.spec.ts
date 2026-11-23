import { expect } from "chai";
import { describe, test } from "mocha";

import { Block, Job } from "./model";
import { BLOCK, BLOCK_HEAD_H, GROUP_ROW_H, JOB_ROW_H, OPEN_BLOCK_W, WIDE_BLOCK_W, blockSize, jobRow, jobRows } from "./lines";

const job = (key: string, name: string) => ({ key, id: null, name, status: `passed`, startedAt: null, finishedAt: null, reused: false }) as Job;
const block = (name: string, jobs: Job[] = []) => ({ id: name, name, deps: [], jobs }) as Block;

const LONG = `integration tests against the staging database with a name far wider than any block`;

describe(`block sizes on the map`, () => {
  test(`a collapsed block has one size whatever its name`, () => {
    expect(blockSize(block(`lint`), false)).to.deep.equal(BLOCK);
    expect(blockSize(block(LONG), false)).to.deep.equal(BLOCK);
  });

  test(`an open block is one row per job when every name fits on one line`, () => {
    expect(blockSize(block(`lint`, [job(`a`, `lint`)]), true)).to.deep.equal({ w: OPEN_BLOCK_W, h: BLOCK_HEAD_H + JOB_ROW_H + 8 });
    expect(blockSize(block(LONG, [job(`a`, `lint`), job(`b`, `unit`)]), true)).to.deep.equal({ w: OPEN_BLOCK_W, h: BLOCK_HEAD_H + 2 * JOB_ROW_H + 8 });
  });

  test(`an open block with a long job name grows wider and gives that name more lines`, () => {
    const { w, rows } = jobRows(block(`it`, [job(`a`, `lint`), job(`b`, LONG)]));
    expect(w).to.equal(WIDE_BLOCK_W);
    expect(rows[0].h).to.equal(JOB_ROW_H);
    expect(rows[1].h).to.be.oneOf([JOB_ROW_H + 16, JOB_ROW_H + 32]);
    expect(blockSize(block(`it`, [job(`a`, `lint`), job(`b`, LONG)]), true).h).to.equal(BLOCK_HEAD_H + JOB_ROW_H + rows[1].h + 8);
  });

  test(`jobs of one matrix show their shared name once, above the values that tell them apart`, () => {
    const b = block(`bats`, [
      job(`a`, `Non-cache tests - TEST=tests/a.bats`),
      job(`b`, `Cache tests - TEST=tests/b.bats, METHOD=native`),
      job(`c`, `Non-cache tests - TEST=tests/c.bats`),
      job(`d`, `Cache tests - TEST=tests/d.bats, METHOD=shell-out`),
      job(`e`, `Shell check - LEVEL=1`),
    ]);
    expect(jobRows(b).rows.map((r) => [r.text, r.job?.key ?? null])).to.deep.equal([
      [`Non-cache tests · TEST`, null],
      [`tests/a.bats`, `a`],
      [`tests/c.bats`, `c`],
      [`Cache tests · TEST, METHOD`, null],
      [`tests/b.bats · native`, `b`],
      [`tests/d.bats · shell-out`, `d`],
      [`Shell check - LEVEL=1`, `e`],
    ]);
  });

  test(`a matrix whose jobs set different variables keeps the variable names in each row`, () => {
    const b = block(`m`, [job(`a`, `Sem - A=1`), job(`b`, `Sem - B=2, C=x=y`)]);
    expect(jobRows(b).rows.map((r) => r.text)).to.deep.equal([`Sem`, `A=1`, `B=2, C=x=y`]);
  });

  test(`each job row starts where the row above it ends`, () => {
    const b = block(`m`, [job(`a`, `Sem - T=gcc`), job(`b`, `Sem - T=go`), job(`c`, `lint`)]);
    expect([0, 1, 2].map((i) => jobRow(b, i).top)).to.deep.equal([BLOCK_HEAD_H + GROUP_ROW_H, BLOCK_HEAD_H + GROUP_ROW_H + JOB_ROW_H, BLOCK_HEAD_H + GROUP_ROW_H + 2 * JOB_ROW_H]);
  });
});
