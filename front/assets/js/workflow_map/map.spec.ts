import { expect } from "chai";
import { describe, test } from "mocha";

import { Block, Job, Pipeline, Workflow } from "./model";
import { closeAllPipelines, firstView, nextView, openBlocks, openPipelines, seedBlocks, structureKey } from "./map";

const job = (status: string) => ({ key: status, id: null, name: status, status, startedAt: null, finishedAt: null, reused: false }) as Job;

const workflowWith = (statuses: string[]) => {
  const block = { id: `b`, name: `lint`, deps: [], jobs: statuses.map(job) } as Block;
  const pipeline = { id: `p`, parent: null, blocks: [block], promotions: [] } as unknown as Pipeline;
  return { pipelines: [pipeline] } as unknown as Workflow;
};

describe(`structureKey`, () => {
  test(`stays the same when only a collapsed block's job states change`, () => {
    const open = new Set([`p`]);
    const before = structureKey(workflowWith([`passed`, `passed`, `passed`, `passed`, `passed`]), open, new Set());
    const after = structureKey(workflowWith([`failed`, `running`, `queued`, `stopped`, `passed`]), open, new Set());
    expect(after).to.equal(before);
  });

  test(`changes when an open block gains a job`, () => {
    const open = new Set([`p`]);
    const before = structureKey(workflowWith([`passed`]), open, new Set([`b`]));
    const after = structureKey(workflowWith([`passed`, `passed`]), open, new Set([`b`]));
    expect(after).to.not.equal(before);
  });

  test(`changes when a pipeline gets its init job`, () => {
    const wf = workflowWith([`passed`]);
    const before = structureKey(wf, new Set([`p`]), new Set());
    wf.pipelines[0].initJob = { url: `/jobs/init`, status: `passed`, started_at: 1, finished_at: 8 };
    expect(structureKey(wf, new Set([`p`]), new Set())).to.not.equal(before);
  });

  test(`changes when the stop details of a stopped pipeline open, and only then`, () => {
    const wf = workflowWith([`passed`]);
    const p = wf.pipelines[0];
    Object.assign(p, { status: `passed`, resultReason: null });
    expect(structureKey(wf, new Set([`p`]), new Set(), new Set([`p`]))).to.equal(structureKey(wf, new Set([`p`]), new Set()));
    Object.assign(p, { status: `stopped`, resultReason: `STRATEGY` });
    expect(structureKey(wf, new Set([`p`]), new Set(), new Set([`p`]))).to.not.equal(structureKey(wf, new Set([`p`]), new Set()));
  });

  test(`changes when the after-pipeline node of a closed pipeline opens`, () => {
    const wf = workflowWith([`passed`]);
    wf.pipelines[0].blocks.push({ id: `a`, name: `After pipeline`, deps: [], jobs: [job(`passed`)], after: true } as Block);
    const before = structureKey(wf, new Set(), new Set());
    const after = structureKey(wf, new Set(), new Set([`a`]));
    expect(after).to.not.equal(before);
  });
});

describe(`seedBlocks`, () => {
  const blk = (p: string, name: string, statuses: string[]) => ({ id: `${p}/${name}`, name, deps: [], jobs: statuses.map(job) }) as Block;
  const pipe = (id: string, done: boolean, blocks: Block[] | null) => ({ id, done, blocks }) as unknown as Pipeline;
  const blocksOf = (p: string) => [blk(p, `lint`, [`passed`]), blk(p, `unit`, [`failed`, `passed`]), blk(p, `e2e`, [`running`, `queued`]), blk(p, `docs`, [`queued`])];
  const ids = (s: Set<string> | null) => [...(s ?? [])].sort();
  const big = (p: string) => blk(p, `matrix`, Array<string>(200).fill(`passed`));

  test(`opens every block of a pipeline that has not finished`, () => {
    const seeded = new Set<string>();
    expect(ids(seedBlocks([pipe(`p`, false, blocksOf(`p`))], new Set([`p`]), seeded, new Set([`q/x`])))).to.deep.equal([`p/docs`, `p/e2e`, `p/lint`, `p/unit`, `q/x`]);
    expect([...seeded]).to.deep.equal([`p`]);
  });

  test(`opens every block of a finished pipeline, however many jobs it has`, () => {
    const done = pipe(`p`, true, [blk(`p`, `lint`, [`passed`]), blk(`p`, `unit`, [`failed`, `passed`]), blk(`p`, `docs`, [`stopped`]), big(`p`)]);
    expect(ids(seedBlocks([done], new Set([`p`]), new Set(), new Set()))).to.deep.equal([`p/docs`, `p/lint`, `p/matrix`, `p/unit`]);
  });

  test(`seeds a pipeline once, so a block the user closed stays closed, also after the pipeline finishes`, () => {
    const seeded = new Set<string>();
    seedBlocks([pipe(`p`, false, blocksOf(`p`))], new Set([`p`]), seeded, new Set());
    const closed = new Set([`p/lint`, `p/e2e`, `p/docs`]);
    expect(seedBlocks([pipe(`p`, false, blocksOf(`p`))], new Set([`p`]), seeded, closed)).to.equal(null);
    expect(seedBlocks([pipe(`p`, true, blocksOf(`p`))], new Set([`p`]), seeded, closed)).to.equal(null);
  });

  test(`Close all pipelines keeps the blocks' state, so a pipeline opened again shows its blocks as they were`, () => {
    const seeded = new Set<string>();
    openPipelines.value = new Set([`p`]);
    openBlocks.value = seedBlocks([pipe(`p`, true, blocksOf(`p`))], openPipelines.value, seeded, new Set()) ?? new Set();
    closeAllPipelines();
    expect([...openPipelines.value]).to.deep.equal([]);
    openPipelines.value = new Set([`p`]);
    expect(seedBlocks([pipe(`p`, true, blocksOf(`p`))], openPipelines.value, seeded, openBlocks.value)).to.equal(null);
    expect(ids(openBlocks.value)).to.deep.equal([`p/docs`, `p/e2e`, `p/lint`, `p/unit`]);
    openPipelines.value = new Set();
    openBlocks.value = new Set();
  });

  test(`waits for a pipeline to be open and its blocks loaded`, () => {
    const seeded = new Set<string>();
    expect(seedBlocks([pipe(`p`, false, blocksOf(`p`)), pipe(`q`, false, null), pipe(`r`, false, [])], new Set([`q`, `r`]), seeded, new Set())).to.equal(null);
    expect(seeded.size).to.equal(0);
  });
});

describe(`nextView`, () => {
  const vw = 1000;
  const vh = 600;
  const block = { x: 400, y: 200, w: 300, h: 100 };

  test(`keeps the zoom and moves the map by how far the anchored box moved`, () => {
    const v = { x: 10, y: 20, zoom: 0.5 };
    expect(nextView(`keep`, block, 1.6, v, vw, vh, { x: 380, y: 260 })).to.deep.equal({ x: 0, y: 50, zoom: 0.5 });
  });

  test(`after anchoring an opened box, moves the map only as far as it takes to show the box`, () => {
    const v = { x: 0, y: 0, zoom: 1 };
    expect(nextView(`open`, block, 1, v, vw, vh, { x: 400, y: 200 })).to.deep.equal(v);
    expect(nextView(`open`, { x: 400, y: 200, w: 300, h: 500 }, 1, v, vw, vh, { x: 400, y: 200 })).to.deep.equal({ x: 0, y: -140, zoom: 1 });
    expect(nextView(`open`, { x: 400, y: 200, w: 900, h: 900 }, 1, v, vw, vh, { x: 400, y: 200 })).to.deep.equal({ x: -340, y: -160, zoom: 1 });
  });

  test(`brings an opened box whose corner sat past the top or left edge back in, 40 px from the edge`, () => {
    const tall = { x: 400, y: 200, w: 300, h: 500 };
    expect(nextView(`open`, tall, 1, { x: 0, y: -180, zoom: 1 }, vw, vh, { x: 400, y: 200 })).to.deep.equal({ x: 0, y: -160, zoom: 1 });
    expect(nextView(`open`, block, 1, { x: -390, y: 0, zoom: 1 }, vw, vh, { x: 400, y: 200 })).to.deep.equal({ x: -360, y: 0, zoom: 1 });
  });

  test(`fits the box on the screen, never past 100%`, () => {
    expect(nextView(`fit`, { x: 0, y: 0, w: 2000, h: 800 }, 1, { x: 0, y: 0, zoom: 1 }, vw, vh)).to.deep.equal({ x: 0, y: 100, zoom: 0.5 });
    expect(nextView(`fit`, block, 1.6, { x: 0, y: 0, zoom: 0.2 }, vw, vh).zoom).to.equal(1);
  });

  test(`fits a box too tall for the screen by its width, at no less than 75%, from its top`, () => {
    expect(nextView(`fit`, { x: 0, y: 0, w: 1000, h: 6000 }, 1, { x: 0, y: 0, zoom: 1 }, vw, vh)).to.deep.equal({ x: 125, y: 64, zoom: 0.75 });
    expect(nextView(`fit`, { x: 0, y: 0, w: 4000, h: 6000 }, 1, { x: 0, y: 0, zoom: 1 }, vw, vh)).to.deep.equal({ x: 0, y: 64, zoom: 0.25 });
  });

  test(`starts a box that would reach under the map's toolbar below it, 64 px from the top`, () => {
    expect(nextView(`fit`, { x: 0, y: 0, w: 2000, h: 1000 }, 1, { x: 0, y: 0, zoom: 1 }, vw, vh)).to.deep.equal({ x: 0, y: 64, zoom: 0.5 });
  });

  test(`leaves the map alone when the focused box is on screen and readable`, () => {
    expect(nextView(`focus`, block, 1.6, { x: 0, y: 0, zoom: 1 }, vw, vh)).to.equal(null);
    expect(nextView(`focus`, block, 1.6, { x: 0, y: 0, zoom: 0.8 }, vw, vh)).to.equal(null);
  });

  test(`centres an off-screen box without changing a readable zoom`, () => {
    expect(nextView(`focus`, block, 1.6, { x: -600, y: 0, zoom: 1 }, vw, vh)).to.deep.equal({ x: -50, y: 50, zoom: 1 });
  });

  test(`treats a box within 40 px of an edge, where the map's own controls sit, as off-screen`, () => {
    expect(nextView(`focus`, block, 1.6, { x: -380, y: 0, zoom: 1 }, vw, vh)).to.deep.equal({ x: -50, y: 50, zoom: 1 });
    expect(nextView(`focus`, block, 1.6, { x: 0, y: 280, zoom: 1 }, vw, vh)).to.deep.equal({ x: -50, y: 50, zoom: 1 });
  });

  test(`zooms a far-out map in only up to 75%, and never out`, () => {
    expect(nextView(`focus`, block, 1.6, { x: 0, y: 0, zoom: 0.3 }, vw, vh).zoom).to.equal(0.75);
    expect(nextView(`focus`, { x: 0, y: 0, w: 4000, h: 3000 }, 1.6, { x: 0, y: 0, zoom: 0.5 }, vw, vh).zoom).to.equal(0.5);
  });

  test(`puts the top of a focused box taller than the screen under the map's toolbar instead of centring it`, () => {
    const tall = { x: 400, y: 0, w: 300, h: 3000 };
    expect(nextView(`focus`, tall, 1.12, { x: 0, y: -5000, zoom: 0.75 }, vw, vh)).to.deep.equal({ x: 87.5, y: 64, zoom: 0.75 });
  });
});

describe(`firstView`, () => {
  const v = { x: 0, y: 0, zoom: 1 };

  test(`shows the whole workflow when it is at least as readable as the initial pipeline`, () => {
    const all = { x: 0, y: 0, w: 900, h: 500 };
    const root = { x: 0, y: 100, w: 200, h: 100 };
    expect(firstView(all, root, v, 1000, 600)).to.deep.equal(nextView(`fit`, all, 1.12, v, 1000, 600));
  });

  test(`starts at the initial pipeline's top-left corner at its readable zoom when the whole workflow is too small to read`, () => {
    const all = { x: 0, y: 0, w: 6000, h: 9000 };
    const root = { x: 0, y: 4000, w: 1000, h: 3000 };
    const next = firstView(all, root, v, 1000, 600);
    expect(next.zoom).to.equal(0.75);
    expect(next.x).to.equal(40);
    expect(next.y).to.equal(64 - 4000 * 0.75);
  });
});
