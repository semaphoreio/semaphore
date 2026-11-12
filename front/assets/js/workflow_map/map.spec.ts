import { expect } from "chai";
import { describe, test } from "mocha";

import { Block, Job, Pipeline, Workflow } from "./model";
import { nextView, structureKey } from "./map";

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

  test(`changes when the after-pipeline node of a closed pipeline opens`, () => {
    const wf = workflowWith([`passed`]);
    wf.pipelines[0].blocks.push({ id: `a`, name: `After pipeline`, deps: [], jobs: [job(`passed`)], after: true } as Block);
    const before = structureKey(wf, new Set(), new Set());
    const after = structureKey(wf, new Set(), new Set([`a`]));
    expect(after).to.not.equal(before);
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

  test(`fits the box on the screen, never past 100%`, () => {
    expect(nextView(`fit`, { x: 0, y: 0, w: 2000, h: 1000 }, 1, { x: 0, y: 0, zoom: 1 }, vw, vh)).to.deep.equal({ x: 0, y: 50, zoom: 0.5 });
    expect(nextView(`fit`, block, 1.6, { x: 0, y: 0, zoom: 0.2 }, vw, vh).zoom).to.equal(1);
  });

  test(`leaves the map alone when the focused box is on screen and readable`, () => {
    expect(nextView(`focus`, block, 1.6, { x: 0, y: 0, zoom: 1 }, vw, vh)).to.equal(null);
    expect(nextView(`focus`, block, 1.6, { x: 0, y: 0, zoom: 0.8 }, vw, vh)).to.equal(null);
  });

  test(`centres an off-screen box without changing a readable zoom`, () => {
    expect(nextView(`focus`, block, 1.6, { x: -600, y: 0, zoom: 1 }, vw, vh)).to.deep.equal({ x: -50, y: 50, zoom: 1 });
  });

  test(`zooms a far-out map in only up to 75%, and never out`, () => {
    expect(nextView(`focus`, block, 1.6, { x: 0, y: 0, zoom: 0.3 }, vw, vh).zoom).to.equal(0.75);
    expect(nextView(`focus`, { x: 0, y: 0, w: 4000, h: 3000 }, 1.6, { x: 0, y: 0, zoom: 0.5 }, vw, vh).zoom).to.equal(0.5);
  });

  test(`puts the top of a focused box taller than the screen near the top edge instead of centring it`, () => {
    const tall = { x: 400, y: 0, w: 300, h: 3000 };
    expect(nextView(`focus`, tall, 1.12, { x: 0, y: -5000, zoom: 0.75 }, vw, vh)).to.deep.equal({ x: 87.5, y: 40, zoom: 0.75 });
  });
});
