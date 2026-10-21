import { expect } from "chai";
import { describe, test } from "mocha";

import { AFTER_PIPELINE, ApiPipeline, ApiPipelineDetail, buildWorkflow, formatDuration, rollup } from "./model";

const apiPipeline = (id: string, overrides: Partial<ApiPipeline> = {}): ApiPipeline => ({
  id,
  name: id,
  yaml_file: `.semaphore/semaphore.yml`,
  state: `DONE`,
  result: `PASSED`,
  parent_id: null,
  trigger: `INITIAL_WORKFLOW`,
  switch_id: null,
  created_at: 1,
  running_at: 10,
  done_at: 20,
  ...overrides,
});

const job = (name: string, status: ApiPipelineDetail[`blocks`][number][`jobs`][number][`status`] = `passed`) => ({
  id: `${name}-id`,
  name,
  status,
  started_at: 10,
  finished_at: 20,
  reused: false,
});

describe(`buildWorkflow`, () => {
  test(`links promotions and partial reruns under their parent and numbers repeated promotions`, () => {
    const wf = buildWorkflow(
      {
        root_pipeline_id: `ci`,
        pipelines: [
          apiPipeline(`deploy-2`, { name: `Deploy`, parent_id: `ci`, created_at: 3 }),
          apiPipeline(`ci`),
          apiPipeline(`deploy-1`, { name: `Deploy`, parent_id: `ci`, created_at: 2 }),
          apiPipeline(`rerun`, { name: `ci`, parent_id: `deploy-1`, trigger: `PIPELINE_PARTIAL_RERUN` }),
        ],
      },
      {}
    );

    expect(wf.root.id).to.eq(`ci`);
    expect(wf.pipelines.map((p) => p.id)).to.deep.eq([`ci`, `deploy-1`, `rerun`, `deploy-2`]);
    expect(wf.pipelineById.get(`deploy-1`).attempt).to.eq(1);
    expect(wf.pipelineById.get(`deploy-2`).attempt).to.eq(2);
    expect(wf.pipelineById.get(`rerun`).depth).to.eq(2);
    expect(wf.root.blocks).to.eq(null);
  });

  test(`maps pipeline states to statuses`, () => {
    const wf = buildWorkflow(
      {
        root_pipeline_id: `a`,
        pipelines: [
          apiPipeline(`a`),
          apiPipeline(`b`, { parent_id: `a`, result: `FAILED` }),
          apiPipeline(`c`, { parent_id: `a`, result: `CANCELED` }),
          apiPipeline(`d`, { parent_id: `a`, state: `RUNNING` }),
          apiPipeline(`e`, { parent_id: `a`, state: `QUEUING` }),
        ],
      },
      {}
    );

    expect(wf.pipelines.map((p) => p.status)).to.deep.eq([`passed`, `failed`, `stopped`, `running`, `queued`]);
  });

  test(`builds blocks with dependencies and an after pipeline block that follows the last blocks`, () => {
    const detail: ApiPipelineDetail = {
      id: `ci`,
      state: `DONE`,
      result: `PASSED`,
      error_description: ``,
      done: true,
      blocks: [
        { name: `Build`, dependencies: [], jobs: [job(`compile`)] },
        { name: `Unit`, dependencies: [`Build`], jobs: [job(`unit 1`), job(`unit 2`, `failed`)] },
        { name: `Lint`, dependencies: [`Build`], jobs: [job(`lint`)] },
      ],
      after_jobs: [job(`cleanup`)],
    };

    const wf = buildWorkflow({ root_pipeline_id: `ci`, pipelines: [apiPipeline(`ci`)] }, { ci: detail });
    const blocks = wf.root.blocks;

    expect(blocks.map((b) => b.name)).to.deep.eq([`Build`, `Unit`, `Lint`, AFTER_PIPELINE]);
    expect(blocks[1].deps.map((b) => b.name)).to.deep.eq([`Build`]);
    expect(blocks[3].deps.map((b) => b.name)).to.deep.eq([`Unit`, `Lint`]);
    expect(wf.jobs.get(`ci/Unit#1`).status).to.eq(`failed`);
    expect(wf.blocks.get(`ci/Lint`).pipeline).to.eq(wf.root);
  });
});

describe(`rollup`, () => {
  test(`picks the status that needs attention`, () => {
    expect(rollup([])).to.eq(`pending`);
    expect(rollup([`passed`, `passed`])).to.eq(`passed`);
    expect(rollup([`passed`, `failed`])).to.eq(`failed`);
    expect(rollup([`failed`, `running`])).to.eq(`running`);
    expect(rollup([`passed`, `skipped`])).to.eq(`passed`);
    expect(rollup([`passed`, `pending`])).to.eq(`running`);
    expect(rollup([`failed`, `stopped`])).to.eq(`failed`);
  });
});

describe(`formatDuration`, () => {
  test(`matches the server side duration format`, () => {
    expect(formatDuration(0)).to.eq(`00:00`);
    expect(formatDuration(65)).to.eq(`01:05`);
    expect(formatDuration(3600 + 61)).to.eq(`01:01:01`);
    expect(formatDuration(86400 * 2 + 5)).to.eq(`2d 00:00:05`);
  });
});
