import { expect } from "chai";
import { describe, test } from "mocha";

import { Block, Job, Pipeline, Workflow } from "./model";
import { structureKey } from "./map";

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
