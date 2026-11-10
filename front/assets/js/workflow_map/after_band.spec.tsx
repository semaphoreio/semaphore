import { expect } from "chai";
import { afterEach, beforeEach, describe, test } from "mocha";
import { render } from "preact";
import { act } from "preact/test-utils";

import { AFTER_HEAD_H, AfterBand, afterBand, openBlocks } from "./map";
import { JOB_ROW_H } from "./lines";
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

  test(`takes the head's height when closed, plus a row per job when open, and nothing without an after pipeline`, () => {
    expect(afterBand(without, new Set())).to.equal(0);
    expect(afterBand(withAfter, new Set())).to.equal(AFTER_HEAD_H);
    expect(afterBand(withAfter, new Set([after.id]))).to.equal(AFTER_HEAD_H + 2 * JOB_ROW_H + 6);
  });

  test(`is collapsed by default and opens to its jobs on a click`, async () => {
    await act(() => render(<AfterBand block={after}/>, root));
    const head = root.querySelector(`.wf-map-after-head`);
    expect(head.getAttribute(`aria-expanded`)).to.equal(`false`);
    expect(head.textContent).to.contain(`After pipeline`);
    expect(head.textContent).to.contain(`2 jobs`);
    expect(root.querySelectorAll(`.wf-map-job`)).to.have.length(0);

    await act(() => {
      head.dispatchEvent(new MouseEvent(`click`, { bubbles: true, detail: 0 }));
    });

    expect(root.querySelector(`.wf-map-after-head`).getAttribute(`aria-expanded`)).to.equal(`true`);
    expect([...root.querySelectorAll(`.wf-map-job-name`)].map((n) => n.textContent)).to.deep.equal([`Cleanup`, `Notify`]);
  });
});
