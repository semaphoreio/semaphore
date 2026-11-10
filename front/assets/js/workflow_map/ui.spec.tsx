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

  test(`a pipeline title shows the full name, selectable in place, with no tooltip, and keeps the attempt out of it`, async () => {
    const p = { name: `a very long pipeline name`, attempt: 2 } as Pipeline;

    await act(() => render(<PipelineTitle p={p}/>, root));

    const name = root.querySelector(`.wf-map-title-name`);
    expect(name.classList.contains(`wf-map-name`)).to.equal(true);
    expect(name.classList.contains(`nopan`)).to.equal(true);
    expect(name.textContent).to.equal(p.name);
    expect(root.querySelector(`[data-tippy-content], [title]`)).to.equal(null);
    expect(root.querySelector(`.wf-map-title-name .wf-map-attempt`)).to.equal(null);
    expect(root.querySelector(`.wf-map-attempt`).textContent).to.equal(`#2`);
  });

  test(`an open block shows the full block and job names with no name tooltips and no measured heights`, async () => {
    const job = { key: `b#0`, id: null, name: `a very long job name`, status: `passed`, startedAt: null, finishedAt: null, reused: false } as Job;
    const block = { id: `b`, name: `a very long block name`, deps: [], jobs: [job] } as Block;

    await act(() => render(<BlockCard block={block}/>, root));

    expect(root.querySelector(`.wf-map-block-head`).getAttribute(`data-tippy-content`)).to.equal(`Collapse the block`);
    expect(root.querySelector(`.wf-map-block-head .wf-map-name`).textContent).to.equal(block.name);
    expect(root.querySelector(`.wf-map-job-name`).textContent).to.equal(job.name);
    expect(root.querySelectorAll(`.wf-map-name [data-tippy-content], .wf-map-name[data-tippy-content], [title]`)).to.have.length(0);
    expect(root.querySelector<HTMLElement>(`.wf-map-job`).style.height).to.equal(``);
  });

  test(`a collapsed block shows the full name, selectable in place`, async () => {
    const block = { id: `b`, name: `a very long block name`, deps: [], jobs: [] } as Block;

    await act(() => render(<BlockSummary block={block} onClick={() => undefined}/>, root));

    const name = root.querySelector(`.wf-map-summary-name .wf-map-block-name`);
    expect(name.classList.contains(`wf-map-name`)).to.equal(true);
    expect(name.hasAttribute(`data-tippy-content`)).to.equal(false);
    expect(name.textContent).to.equal(block.name);
  });

  test(`a click that ends a text selection inside a block does not toggle it`, async () => {
    const block = { id: `b`, name: `a very long block name`, deps: [], jobs: [] } as Block;
    let toggled = 0;

    await act(() => render(<BlockSummary block={block} onClick={() => toggled++}/>, root));

    const button = root.querySelector<HTMLButtonElement>(`.wf-map-summary`);
    button.click();
    window.getSelection().selectAllChildren(root.querySelector(`.wf-map-name-text`));
    button.click();
    window.getSelection().removeAllRanges();
    expect(toggled).to.equal(1);
  });
});
