import { expect } from "chai";
import { after, before, describe, test } from "mocha";
import { Worker as ElkWorker } from "elkjs/lib/elk-worker.min.js";

import { Block, Pipeline, Workflow } from "./model";
import { MIN_OPEN_W, MapLayout, initLayout, layoutMap } from "./layout";

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

const workflowOf = (blocks: [string, string[]][]) => {
  const pipeline = { id: `p`, name: `Build`, parent: null, blocks: [], promotions: [] } as unknown as Pipeline;
  for (const [name, deps] of blocks) {
    pipeline.blocks.push({ id: name, name, deps: deps.map((d) => pipeline.blocks.find((b) => b.name === d)), jobs: [], pipeline } as Block);
  }
  return { pipelines: [pipeline] } as unknown as Workflow;
};

const layout = (wf: Workflow, open: boolean) => layoutMap(wf, () => open, () => SIZE, CLOSED);

const grown = (wf: Workflow, name: string | null, dw: number, dh: number) =>
  layoutMap(wf, () => true, (b) => (b.name === name ? { w: SIZE.w + dw, h: SIZE.h + dh } : SIZE), CLOSED);

const moves = (before: MapLayout, after: MapLayout) =>
  Object.fromEntries([...before.blocks].map(([id, b]) => [id, [after.blocks.get(id).x - b.x, after.blocks.get(id).y - b.y]]));

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

  test(`widens the pipeline by the after block and leaves the other blocks where they are`, async () => {
    const plain = await layout(workflowWith([`build`, `test`], true), true);
    const withAfter = await layout(workflowWith([`build`, `test`], true, true), true);
    expect(withAfter.blocks.get(`build`)).to.deep.equal(plain.blocks.get(`build`));
    expect(withAfter.blocks.get(`test`)).to.deep.equal(plain.blocks.get(`test`));
    expect(withAfter.pipelines.get(`p`).w - plain.pipelines.get(`p`).w).to.equal(64 + SIZE.w);
    expect(withAfter.pipelines.get(`p`).h).to.equal(plain.pipelines.get(`p`).h);
  });

  test(`grows the pipeline to hold an after block taller than the other blocks`, async () => {
    const wf = workflowWith([`build`], false, true);
    const tall = await layoutMap(wf, () => true, (b) => (b.after ? { w: SIZE.w, h: SIZE.h + 300 } : SIZE), CLOSED);
    expect(tall.pipelines.get(`p`).h - (await layout(wf, true)).pipelines.get(`p`).h).to.equal(300);
  });

  test(`moves the blocks and the after block down to leave room for the init tab, and grows the pipeline by it`, async () => {
    const plain = await layout(workflowWith([`build`], false, true), true);
    const wf = workflowWith([`build`], false, true);
    wf.pipelines[0].initJob = { url: `/jobs/init`, status: `passed`, started_at: 1, finished_at: 8 };
    const tabbed = await layout(wf, true);
    expect(tabbed.blocks.get(`after`).y - plain.blocks.get(`after`).y).to.equal(10);
    expect(tabbed.blocks.get(`build`).y - plain.blocks.get(`build`).y).to.equal(10);
    expect(tabbed.pipelines.get(`p`).h - plain.pipelines.get(`p`).h).to.equal(10);
  });

  test(`moves the blocks and the after block down by the details band under the header`, async () => {
    const wf = workflowWith([`build`], false, true);
    const plain = await layout(wf, true);
    const detailed = await layoutMap(wf, () => true, () => SIZE, CLOSED, () => 44);
    expect(detailed.blocks.get(`after`).y - plain.blocks.get(`after`).y).to.equal(44);
    expect(detailed.blocks.get(`build`).y - plain.blocks.get(`build`).y).to.equal(44);
    expect(detailed.pipelines.get(`p`).h - plain.pipelines.get(`p`).h).to.equal(44);
  });

  test(`keeps the init tab's room under an open details band, so the tab hangs from the band`, async () => {
    const plain = await layout(workflowWith([`build`], false, true), true);
    const wf = workflowWith([`build`], false, true);
    wf.pipelines[0].initJob = { url: `/jobs/init`, status: `passed`, started_at: 1, finished_at: 8 };
    const detailed = await layoutMap(wf, () => true, () => SIZE, CLOSED, () => 48);
    expect(detailed.blocks.get(`after`).y - plain.blocks.get(`after`).y).to.equal(48 + 10);
    expect(detailed.blocks.get(`build`).y - plain.blocks.get(`build`).y).to.equal(48 + 10);
  });

  test(`opens a block without reordering: earlier blocks stay, its row's later blocks move right by its growth, later rows move down`, async () => {
    const wf = workflowOf([`a`, `b`, `c`, `d`, `e`, `f`, `g`, `h`].map((name): [string, string[]] => [name, []]));
    const before = await grown(wf, null, 0, 0);
    const after = await grown(wf, `e`, 20, 420);
    expect(moves(before, after)).to.deep.equal({ a: [0, 0], b: [0, 0], c: [0, 0], d: [0, 0], e: [0, 0], f: [20, 0], g: [0, 420], h: [0, 420] });
  });

  test(`lays out groups with dependencies in rows, routes their edges to the blocks, and opening a first-row block only moves the later rows down`, async () => {
    const wf = workflowOf([[`a1`, []], [`a2`, [`a1`]], [`a3`, [`a2`]], [`b1`, []], [`b2`, [`b1`]], [`c`, []], [`d`, []], [`f1`, []], [`f2`, [`f1`]], [`f3`, [`f1`]]]);
    const before = await grown(wf, null, 0, 0);
    const after = await grown(wf, `a2`, 20, 220);
    const p = before.pipelines.get(`p`);
    expect([...before.routes.keys()]).to.have.members([`a1->a2`, `a2->a3`, `b1->b2`, `f1->f2`, `f1->f3`]);
    for (const [id, points] of before.routes) {
      const [from, to] = id.split(`->`).map((name) => before.blocks.get(name));
      const [start, end] = [points[0], points[points.length - 1]];
      expect(start.x, id).to.equal(p.x + from.x + from.w);
      expect(start.y - p.y, id).to.be.within(from.y, from.y + from.h);
      expect(end.x, id).to.equal(p.x + to.x);
      expect(end.y - p.y, id).to.be.within(to.y, to.y + to.h);
    }
    expect(moves(before, after)).to.deep.include({ a2: [0, 0], b1: [0, 220], b2: [0, 220], c: [0, 220], d: [0, 220], f1: [0, 220], f2: [0, 220], f3: [0, 220] });
  });

  test(`places the groups in the order of the pipeline's YAML, not by size`, async () => {
    const L = await layout(workflowOf([[`f1`, []], [`f2`, [`f1`]], [`f3`, [`f1`]], [`c`, []]]), true);
    expect(L.blocks.get(`c`).y).to.be.greaterThan(L.blocks.get(`f3`).y);
  });

  test(`places the after block last: right of the last block, level with the first row`, async () => {
    const L = await layout(workflowWith([`build`, `test`], true, true), true);
    const last = L.blocks.get(`test`);
    expect(L.blocks.get(`after`)).to.deep.equal({ x: last.x + last.w + 64, y: 88, ...SIZE });
    expect(L.pipelines.get(`p`).w).to.equal(L.blocks.get(`after`).x + SIZE.w + 28);
  });
});
