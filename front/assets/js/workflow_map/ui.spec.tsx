import { expect } from "chai";
import { afterEach, beforeEach, describe, test } from "mocha";
import { render } from "preact";
import { act } from "preact/test-utils";

import { Block, Job, Pipeline } from "./model";
import { BlockCard, BlockSummary, PipelineTitle } from "./ui";

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

    expect(root.querySelector(`.wf-map-title`).getAttribute(`data-tippy-content`)).to.equal(p.name);
    expect(root.querySelector(`[title]`)).to.equal(null);
    expect(root.querySelector(`.wf-map-title-name`).textContent).to.equal(p.name);
    expect(root.querySelector(`.wf-map-title-name .wf-map-attempt`)).to.equal(null);
    expect(root.querySelector(`.wf-map-attempt`).textContent).to.equal(`#2`);
  });

  test(`an open block carries the full block and job names, one tooltip each`, async () => {
    const job = { key: `b#0`, id: null, name: `a very long job name`, status: `passed`, startedAt: null, finishedAt: null, reused: false } as Job;
    const block = { id: `b`, name: `a very long block name`, deps: [], jobs: [job] } as Block;

    await act(() => render(<BlockCard block={block}/>, root));

    expect(root.querySelector(`.wf-map-block-head`).getAttribute(`data-tippy-content`)).to.equal(`Collapse ${block.name}`);
    expect(root.querySelector(`.wf-map-block-head [data-tippy-content]`)).to.equal(null);
    expect(root.querySelector(`.wf-map-job-name`).getAttribute(`data-tippy-content`)).to.equal(job.name);
    expect(root.querySelector(`[title]`)).to.equal(null);
  });

  test(`a job row is one line tall for a short name and two for a long one`, async () => {
    const job = (key: string, name: string) => ({ key, id: null, name, status: `passed`, startedAt: null, finishedAt: null, reused: false }) as Job;
    const block = { id: `b`, name: `build`, deps: [], jobs: [job(`b#0`, `lint`), job(`b#1`, `integration tests against the staging database`)] } as Block;

    await act(() => render(<BlockCard block={block}/>, root));

    const rows = root.querySelectorAll<HTMLElement>(`.wf-map-job`);
    expect(rows[0].style.height).to.equal(`23px`);
    expect(rows[1].style.height).to.equal(`39px`);
  });

  test(`a collapsed block carries the full name on the part that shortens`, async () => {
    const block = { id: `b`, name: `a very long block name`, deps: [], jobs: [] } as Block;

    await act(() => render(<BlockSummary block={block} onClick={() => undefined}/>, root));

    const name = root.querySelector(`.wf-map-summary-name .wf-map-block-name`);
    expect(name.getAttribute(`data-tippy-content`)).to.equal(block.name);
    expect(name.textContent).to.equal(block.name);
  });
});
