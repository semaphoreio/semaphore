import { expect } from "chai";
import { afterEach, beforeEach, describe, test } from "mocha";

import { ApiPipelineDetail } from "./model";
import { Config, cursor, details, focus, focusOn, hits, query, refresh, resetState, results, scope, selected, statuses, step, toggleStatus, tree } from "./store";

const detail = (id: string, blocks: ApiPipelineDetail[`blocks`]): ApiPipelineDetail => ({
  id,
  state: `DONE`,
  result: `PASSED`,
  error_description: ``,
  done: true,
  promotions: [],
  blocks,
  after_jobs: [],
});

const job = (name: string, status: `passed` | `failed` = `passed`) => ({ id: `${name}-id`, name, status, started_at: 1, finished_at: 2, reused: false });

const pipeline = (id: string, name: string, parent_id: string | null) => ({
  id,
  name,
  yaml_file: `.semaphore/${id}.yml`,
  state: `DONE`,
  result: `PASSED`,
  parent_id,
  trigger: `AUTO_PROMOTION`,
  switch_id: null,
  created_at: 1,
  running_at: 1,
  done_at: 2,
  stop_url: null,
  rebuild_url: null,
});

describe(`workflow map store`, () => {
  beforeEach(() => {
    resetState(`ci`);
    tree.value = {
      root_pipeline_id: `ci`,
      pipelines: [pipeline(`ci`, `Build & test`, null), pipeline(`e2e`, `E2E`, `ci`)],
    };
    details.value = {
      ci: detail(`ci`, [{ name: `Unit`, dependencies: [], jobs: [job(`jest 1`), job(`jest 2`, `failed`)] }]),
      e2e: detail(`e2e`, [{ name: `Playwright`, dependencies: [], jobs: [job(`shard 1`, `failed`), job(`shard 2`)] }]),
    };
  });

  test(`a status filter matches jobs across every pipeline in workflow order`, () => {
    toggleStatus(`failed`);

    expect(hits.value.ordered.map((j) => j.name)).to.deep.eq([`jest 2`, `shard 1`]);
    expect(hits.value.pipelines.size).to.eq(2);
  });

  test(`a query on a block name matches all of its jobs`, () => {
    query.value = `playwright`;

    expect(hits.value.ordered.map((j) => j.name)).to.deep.eq([`shard 1`, `shard 2`]);
  });

  test(`stepping through matches wraps around and focuses each job`, () => {
    toggleStatus(`failed`);

    step(1);
    expect(cursor.value).to.eq(0);
    expect(focus.value.id).to.eq(`ci/Unit#1`);

    step(1);
    expect(selected.value).to.eq(`e2e`);

    step(1);
    expect(cursor.value).to.eq(0);

    step(-1);
    expect(cursor.value).to.eq(1);
  });

  test(`search results can be limited to the selected pipeline`, () => {
    query.value = `1`;

    expect(results.value.map((r) => r.label)).to.deep.eq([`jest 1`, `shard 1`]);

    scope.value = `pipeline`;
    selected.value = `e2e`;

    expect(results.value.map((r) => r.label)).to.deep.eq([`shard 1`]);
  });

  test(`combining a query with a status filter narrows the results`, () => {
    query.value = `shard`;
    toggleStatus(`passed`);

    expect(results.value.map((r) => r.label)).to.deep.eq([`shard 2`]);
    expect(statuses.value.has(`passed`)).to.eq(true);
  });

  test(`selecting a pipeline before the first load keeps the selection`, () => {
    resetState(`ci`);
    focusOn(`pipeline`, `e2e`);

    expect(selected.value).to.eq(`e2e`);
    expect(focus.value.id).to.eq(`e2e`);
  });
});

describe(`refresh`, () => {
  const config: Config = {
    workflowUrl: `/wf/map`,
    pipelineUrl: `/ppl/__PIPELINE_ID__/map`,
    elkWorkerUrl: ``,
    selectedPipelineId: `ci`,
    pollInterval: 4000,
  };
  const realFetch = globalThis.fetch;
  let requested: string[];
  let responses: Record<string, unknown>;

  beforeEach(() => {
    resetState(`ci`);
    requested = [];
    responses = {
      "/wf/map": { root_pipeline_id: `ci`, pipelines: [pipeline(`ci`, `Build & test`, null)] },
      "/ppl/ci/map": { ...detail(`ci`, []), done: false },
    };
    globalThis.fetch = ((url: string) => {
      requested.push(url);
      return Promise.resolve(new Response(JSON.stringify(responses[url]), { status: 200 }));
    }) as typeof fetch;
  });

  afterEach(() => {
    globalThis.fetch = realFetch;
  });

  test(`keeps fetching a finished pipeline until its after pipeline jobs are done`, async () => {
    await refresh(config);
    await refresh(config);
    responses[`/ppl/ci/map`] = detail(`ci`, []);
    await refresh(config);
    await refresh(config);

    expect(requested.filter((u) => u === `/ppl/ci/map`).length).to.eq(3);
    expect(details.value.ci.done).to.eq(true);
  });

  test(`fetches a finished pipeline again when a new promoted pipeline appears under it`, async () => {
    responses[`/ppl/ci/map`] = detail(`ci`, []);
    await refresh(config);
    await refresh(config);
    responses[`/wf/map`] = { root_pipeline_id: `ci`, pipelines: [pipeline(`ci`, `Build & test`, null), pipeline(`e2e`, `E2E`, `ci`)] };
    responses[`/ppl/e2e/map`] = detail(`e2e`, []);
    await refresh(config);

    expect(requested.filter((u) => u === `/ppl/ci/map`).length).to.eq(2);
  });

  test(`keeps fetching a finished pipeline while one of its promotions is starting`, async () => {
    responses[`/ppl/ci/map`] = {
      ...detail(`ci`, []),
      promotions: [{ name: `Staging`, trigger_url: `/promote`, can_promote: true, deployment: null, parameters: [], events: [{ pipeline_id: null, processed: false, result: ``, auto: false, triggered_at: 1, author: null }] }],
    };
    await refresh(config);
    await refresh(config);

    expect(requested.filter((u) => u === `/ppl/ci/map`).length).to.eq(2);
  });

  test(`drops the results of a refresh started before the page was left`, async () => {
    const pending = refresh(config);
    resetState(`other`);
    await pending;

    expect(tree.value).to.eq(null);
    expect(details.value).to.deep.eq({});
  });
});
