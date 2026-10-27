import { expect } from "chai";
import { afterEach, beforeEach, describe, test } from "mocha";

import { ApiPipelineDetail } from "./model";
import { Config, cursor, details, focus, focusOn, hits, promote, query, refresh, resetState, results, scope, selected, statuses, step, toggleStatus, tree, workflow } from "./store";

const detail = (id: string, blocks: ApiPipelineDetail[`blocks`]): ApiPipelineDetail => ({
  id,
  state: `DONE`,
  result: `PASSED`,
  error_html: null,
  init_job: null,
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
    pipelinesUrl: `/wf/map/pipelines`,
    elkWorkerUrl: ``,
    selectedPipelineId: `ci`,
    pollInterval: 4000,
  };
  const starting = { name: `Staging`, trigger_url: `/promote`, can_promote: true, deployment: null, parameters: [], events: [{ pipeline_id: null, processed: false, result: ``, auto: false, triggered_at: 1, author: null }] };
  const realFetch = globalThis.fetch;
  let batches: { ids: string[], promotions: string[], }[];
  let served: unknown;
  let pipelines: Record<string, ApiPipelineDetail>;
  let failDetails: boolean;

  const fetchedTimes = (id: string) => batches.filter((b) => b.ids.includes(id)).length;

  beforeEach(() => {
    resetState(`ci`);
    batches = [];
    served = { root_pipeline_id: `ci`, pipelines: [pipeline(`ci`, `Build & test`, null)] };
    pipelines = { ci: { ...detail(`ci`, []), done: false } };
    failDetails = false;
    globalThis.fetch = ((url: string) => {
      const [pathname, query] = url.split(`?`);
      const searchParams = new URLSearchParams(query);
      let body: unknown = served;
      if (pathname === config.pipelinesUrl) {
        const ids = searchParams.get(`ids`).split(`,`);
        const promotions = searchParams.get(`promotions`).split(`,`);
        batches.push({ ids, promotions });
        if (failDetails) return Promise.resolve(new Response(`{}`, { status: 500 }));
        body = { pipelines: ids.map((id) => ({ ...pipelines[id], promotions: promotions.includes(id) ? pipelines[id].promotions : null })) };
      }
      return Promise.resolve(new Response(JSON.stringify(body), { status: 200 }));
    }) as typeof fetch;
  });

  afterEach(() => {
    globalThis.fetch = realFetch;
  });

  test(`fetches every due pipeline in one request`, async () => {
    served = { root_pipeline_id: `ci`, pipelines: [pipeline(`ci`, `Build & test`, null), { ...pipeline(`e2e`, `E2E`, `ci`), state: `RUNNING` }] };
    pipelines.e2e = { ...detail(`e2e`, []), done: false };
    await refresh(config);

    expect(batches).to.deep.eq([{ ids: [`ci`, `e2e`], promotions: [`ci`, `e2e`] }]);
  });

  test(`keeps fetching a finished pipeline until its after pipeline jobs are done`, async () => {
    await refresh(config);
    await refresh(config);
    pipelines.ci = detail(`ci`, []);
    await refresh(config);
    await refresh(config);

    expect(fetchedTimes(`ci`)).to.eq(3);
    expect(details.value.ci.done).to.eq(true);
  });

  test(`skips the promotions of a running pipeline it already knows and keeps the last ones`, async () => {
    served = { root_pipeline_id: `ci`, pipelines: [{ ...pipeline(`ci`, `Build & test`, null), state: `RUNNING` }] };
    pipelines.ci = { ...pipelines.ci, promotions: [{ ...starting, events: [] }] };
    await refresh(config);
    await refresh(config);

    expect(batches.map((b) => b.promotions)).to.deep.eq([[`ci`], [``]]);
    expect(details.value.ci.promotions.map((p) => p.name)).to.deep.eq([`Staging`]);
  });

  test(`fetches a finished pipeline again when a new promoted pipeline appears under it`, async () => {
    pipelines.ci = detail(`ci`, []);
    await refresh(config);
    await refresh(config);
    served = { root_pipeline_id: `ci`, pipelines: [pipeline(`ci`, `Build & test`, null), pipeline(`e2e`, `E2E`, `ci`)] };
    pipelines.e2e = detail(`e2e`, []);
    await refresh(config);

    expect(fetchedTimes(`ci`)).to.eq(2);
    expect(batches.at(-1).promotions).to.deep.eq([`ci`, `e2e`]);
  });

  test(`keeps fetching a finished pipeline while one of its promotions is starting`, async () => {
    pipelines.ci = { ...detail(`ci`, []), promotions: [starting] };
    await refresh(config);
    await refresh(config);

    expect(fetchedTimes(`ci`)).to.eq(2);
  });

  test(`asks again for promotions that didn't come back`, async () => {
    pipelines.ci = { ...detail(`ci`, []), promotions: null };
    await refresh(config);
    pipelines.ci = { ...detail(`ci`, []), promotions: [{ ...starting, events: [] }] };
    await refresh(config);
    await refresh(config);

    expect(batches.map((b) => b.promotions)).to.deep.eq([[`ci`], [`ci`]]);
    expect(details.value.ci.promotions.map((p) => p.name)).to.deep.eq([`Staging`]);
  });

  test(`keeps the refresh after a promote when the request fails`, async () => {
    pipelines.ci = { ...detail(`ci`, []), promotions: [{ ...starting, events: [] }] };
    await refresh(config);
    const ci = workflow.value.pipelineById.get(`ci`);
    await promote(ci, ci.promotions[0], {});
    failDetails = true;
    await refresh(config);
    failDetails = false;
    await refresh(config);
    await refresh(config);

    expect(fetchedTimes(`ci`)).to.eq(3);
  });

  test(`reports whether anything changed`, async () => {
    expect(await refresh(config)).to.eq(true);
    expect(await refresh(config)).to.eq(false);
    pipelines.ci = { ...pipelines.ci, result: `FAILED` };
    expect(await refresh(config)).to.eq(true);
    pipelines.ci = detail(`ci`, []);
    await refresh(config);
    expect(await refresh(config)).to.eq(false);
    expect(batches.length).to.eq(4);
  });

  test(`drops the results of a refresh started before the page was left`, async () => {
    const pending = refresh(config);
    resetState(`other`);
    await pending;

    expect(tree.value).to.eq(null);
    expect(details.value).to.deep.eq({});
  });
});
