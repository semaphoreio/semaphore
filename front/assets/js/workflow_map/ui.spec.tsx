import { expect } from "chai";
import { afterEach, beforeEach, describe, test } from "mocha";
import { render } from "preact";
import { act } from "preact/test-utils";

import { Block, Job, Pipeline } from "./model";
import { BlockCard, PipelineTitle } from "./ui";

describe(`names the map may shorten`, () => {
  let root: HTMLElement;

  beforeEach(() => {
    root = document.createElement(`div`);
    document.body.appendChild(root);
  });

  afterEach(() => {
    render(null, root);
    root.remove();
  });

  test(`a pipeline title carries the full name and keeps the attempt out of the part that shortens`, async () => {
    const p = { name: `a very long pipeline name`, attempt: 2 } as Pipeline;

    await act(() => render(<PipelineTitle p={p}/>, root));

    expect(root.querySelector(`.wf-map-title`).getAttribute(`title`)).to.equal(p.name);
    expect(root.querySelector(`.wf-map-title-name`).textContent).to.equal(p.name);
    expect(root.querySelector(`.wf-map-title-name .wf-map-attempt`)).to.equal(null);
    expect(root.querySelector(`.wf-map-attempt`).textContent).to.equal(`#2`);
  });

  test(`an open block carries the full block and job names`, async () => {
    const job = { key: `b#0`, id: null, name: `a very long job name`, status: `passed`, startedAt: null, finishedAt: null, reused: false } as Job;
    const block = { id: `b`, name: `a very long block name`, deps: [], jobs: [job] } as Block;

    await act(() => render(<BlockCard block={block}/>, root));

    expect(root.querySelector(`.wf-map-block-name`).getAttribute(`title`)).to.equal(block.name);
    expect(root.querySelector(`.wf-map-job-name`).getAttribute(`title`)).to.equal(job.name);
  });
});
