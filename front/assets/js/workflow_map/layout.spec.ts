import { expect } from "chai";
import { after, before, describe, test } from "mocha";
import { Worker as ElkWorker } from "elkjs/lib/elk-worker.min.js";

import { Block, Pipeline, Workflow } from "./model";
import { MIN_OPEN_W, initLayout, layoutMap } from "./layout";

const CLOSED = { w: 300, h: 72 };
const SIZE = { w: 240, h: 80 };

const workflowWith = (names: string[], chain: boolean, after = false) => {
  const pipeline = { id: `p`, name: `Build`, parent: null, blocks: [], promotions: [] } as unknown as Pipeline;
  names.forEach((name, i) => {
    const deps = chain && i > 0 ? [pipeline.blocks[i - 1]] : [];
    pipeline.blocks.push({ id: name, name, deps, jobs: [], pipeline } as Block);
  });
  if (after) pipeline.blocks.push({ id: `after`, name: `After pipeline`, deps: [], jobs: [], pipeline, after: true } as Block);
  return { pipelines: [pipeline] } as unknown as Workflow;
};

const layout = (wf: Workflow, open: boolean, band = 0) => layoutMap(wf, () => open, () => SIZE, CLOSED, () => band);

describe(`layoutMap`, () => {
  const realWorker = globalThis.Worker;

  before(() => {
    globalThis.Worker = class extends ElkWorker {
      addEventListener = () => undefined;
      terminate = () => undefined;
    } as unknown as typeof Worker;
    initLayout(``, () => undefined);
  });

  after(() => {
    globalThis.Worker = realWorker;
  });

  test(`opens a one-block pipeline wide enough for its header actions`, async () => {
    const L = await layout(workflowWith([`build`], false), true);
    expect(L.pipelines.get(`p`).w).to.equal(MIN_OPEN_W);
  });

  test(`opens blocks without dependencies in one column at the minimum width`, async () => {
    const L = await layout(workflowWith([`lint`, `test`, `docs`], false), true);
    expect(L.pipelines.get(`p`).w).to.equal(MIN_OPEN_W);
  });

  test(`keeps a wider pipeline at its own width`, async () => {
    const L = await layout(workflowWith([`build`, `test`, `deploy`], true), true);
    expect(L.pipelines.get(`p`).w).to.be.greaterThan(MIN_OPEN_W);
  });

  test(`keeps a closed pipeline at the card size`, async () => {
    const L = await layout(workflowWith([`build`], false), false);
    expect(L.pipelines.get(`p`)).to.include({ w: CLOSED.w, h: CLOSED.h, open: false });
  });

  test(`moves the blocks down by the after band and grows the pipeline by it`, async () => {
    const wf = workflowWith([`build`], false);
    const plain = await layout(wf, true);
    const banded = await layout(wf, true, 50);
    expect(banded.blocks.get(`build`).y - plain.blocks.get(`build`).y).to.equal(50);
    expect(banded.pipelines.get(`p`).h - plain.pipelines.get(`p`).h).to.equal(50);
  });

  test(`places the after block in its band, above the other blocks`, async () => {
    const L = await layout(workflowWith([`build`], false, true), true, SIZE.h + 20);
    expect(L.blocks.get(`after`)).to.deep.equal({ x: 28, y: 88, ...SIZE });
    expect(L.blocks.get(`build`).y).to.equal(88 + SIZE.h + 20);
  });
});
