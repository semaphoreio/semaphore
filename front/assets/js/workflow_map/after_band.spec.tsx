import { expect } from "chai";
import { afterEach, beforeEach, describe, test } from "mocha";
import { render } from "preact";
import { act } from "preact/test-utils";

import { AfterBand, afterBand, openBlocks } from "./map";
import { BLOCK, BLOCK_GAP, blockSize } from "./lines";
import { Block, Job, Pipeline } from "./model";

const job = (name: string, status: string) => ({ key: `p/After pipeline#${name}`, id: null, name, status, startedAt: null, finishedAt: null, reused: false }) as Job;

describe(`the after pipeline band`, () => {
  let root: HTMLElement;
  const after = { id: `p/After pipeline`, name: `After pipeline`, deps: [], jobs: [job(`Cleanup`, `passed`), job(`Notify`, `failed`)], after: true } as Block;
  const lint = { id: `p/lint`, name: `lint`, deps: [], jobs: [] } as Block;
  const withAfter = { id: `p`, blocks: [lint, after] } as unknown as Pipeline;
  const without = { id: `q`, blocks: [lint] } as unknown as Pipeline;

  beforeEach(() => {
    root = document.createElement(`div`);
    document.body.appendChild(root);
  });

  afterEach(() => {
    render(null, root);
    root.remove();
    openBlocks.value = new Set();
  });

  test(`takes a block card's height plus the gap between blocks, and nothing without an after pipeline`, () => {
    expect(afterBand(without, new Set())).to.equal(0);
    expect(afterBand(withAfter, new Set())).to.equal(BLOCK.h + BLOCK_GAP);
    expect(afterBand(withAfter, new Set([after.id]))).to.equal(blockSize(after, true).h + BLOCK_GAP);
  });

  test(`is a collapsed block card by default and opens to its jobs on a click`, async () => {
    await act(() => render(<AfterBand block={after}/>, root));
    const card = root.querySelector(`.wf-map-after .wf-map-summary`);
    expect(card.getAttribute(`aria-expanded`)).to.equal(`false`);
    expect(card.textContent).to.contain(`After pipeline`);
    expect(card.textContent).to.contain(`2 jobs`);
    expect(root.querySelectorAll(`.wf-map-job`)).to.have.length(0);

    await act(() => {
      card.dispatchEvent(new MouseEvent(`click`, { bubbles: true, detail: 0 }));
    });

    const head = root.querySelector(`.wf-map-after .wf-map-block .wf-map-block-head`);
    expect(head.getAttribute(`aria-expanded`)).to.equal(`true`);
    expect([...root.querySelectorAll(`.wf-map-job-name`)].map((n) => n.textContent)).to.deep.equal([`Cleanup`, `Notify`]);
    const size = root.querySelector<HTMLElement>(`.wf-map-after`).style;
    expect([size.width, size.height]).to.deep.equal([`${blockSize(after, true).w}px`, `${blockSize(after, true).h}px`]);

    await act(() => {
      head.dispatchEvent(new MouseEvent(`click`, { bubbles: true, detail: 0 }));
    });

    expect(root.querySelector(`.wf-map-after .wf-map-summary`)).to.not.equal(null);
  });
});
