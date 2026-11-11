import { expect } from "chai";
import { afterEach, beforeEach, describe, test } from "mocha";
import { render } from "preact";
import { act } from "preact/test-utils";

import { ApiPipelineDetail } from "./model";
import { Popover } from "./popover";
import { details, popover, resetState, tree } from "./store";

const promotion = (name: string) => ({ name, trigger_url: `#`, can_promote: true, deployment: null, parameters: [], events: [] });

const detail = (id: string, promotions: string[]): ApiPipelineDetail => ({
  id,
  state: `DONE`,
  result: `PASSED`,
  error_html: null,
  init_job: null,
  done: true,
  promotions: promotions.map(promotion),
  blocks: [{ name: `Unit`, dependencies: [], jobs: [{ id: `${id}-job`, name: `jest`, status: `passed`, started_at: 1, finished_at: 2, reused: false }] }],
  after_jobs: [],
});

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

describe(`promotions popover`, () => {
  let root: HTMLElement;
  const filter = () => root.querySelector<HTMLInputElement>(`.wf-map-promotion-filter`);
  const names = () => [...root.querySelectorAll(`.wf-map-promotion-name`)].map((n) => n.textContent);
  const openFor = (id: string) =>
    act(() => {
      popover.value = { kind: `promote`, id, x: 0, y: 0 };
    });

  beforeEach(async () => {
    resetState(`ci`);
    tree.value = { root_pipeline_id: `ci`, pipelines: [pipeline(`ci`, `Build & test`, null), pipeline(`deploy`, `Deploy`, `ci`)] };
    details.value = {
      ci: detail(`ci`, [`Deploy`, `Docs`]),
      deploy: detail(`deploy`, [`Production`, `Canary`]),
    };
    root = document.createElement(`div`);
    document.body.appendChild(root);
    await openFor(`ci`);
    await act(() => render(<Popover/>, root));
  });

  afterEach(() => {
    render(null, root);
    root.remove();
    popover.value = null;
    tree.value = null;
    details.value = {};
  });

  test(`opens another pipeline's menu with an empty filter, its full list and the input focused`, async () => {
    await act(() => {
      filter().value = `docs`;
      filter().dispatchEvent(new Event(`input`, { bubbles: true }));
    });
    expect(names()).to.deep.equal([`Docs`]);

    await openFor(`deploy`);

    expect(filter().value).to.equal(``);
    expect(names()).to.deep.equal([`Production`, `Canary`]);
    expect(document.activeElement).to.equal(filter());
  });
});
