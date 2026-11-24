import { expect } from "chai";
import { afterEach, beforeEach, describe, test } from "mocha";
import { render } from "preact";
import { act } from "preact/test-utils";

import { BlocksToggle, openBlocks } from "./map";
import { Block, Pipeline } from "./model";

const block = (p: string, name: string) => ({ id: `${p}/${name}`, name, deps: [], jobs: [], pipeline: { id: p } }) as unknown as Block;
const pipeline = (id: string, blocks: Block[] | null) => ({ id, name: `Pipeline ${id}`, blocks }) as unknown as Pipeline;

describe(`the expand / collapse all blocks control`, () => {
  let root: HTMLElement;
  const p = pipeline(`p`, [block(`p`, `lint`), block(`p`, `test`), block(`p`, `build`)]);
  const q = pipeline(`q`, [block(`q`, `deploy`)]);
  const closed = block(`r`, `smoke`);

  beforeEach(() => {
    root = document.createElement(`div`);
    document.body.appendChild(root);
  });

  afterEach(() => {
    render(null, root);
    root.remove();
    openBlocks.value = new Set();
  });

  const button = () => root.querySelector<HTMLButtonElement>(`.wf-map-blocks-toggle`);
  const click = async () => {
    await act(() => {
      button().dispatchEvent(new MouseEvent(`click`, { bubbles: true }));
    });
  };

  test(`is shown but disabled while blocks load, for pipelines without blocks and with no open pipeline`, async () => {
    for (const pipelines of [[pipeline(`a`, null)], [pipeline(`b`, [])], []]) {
      await act(() => render(<BlocksToggle pipelines={pipelines} anchor={null}/>, root));
      expect(button().disabled).to.equal(true);
      expect(button().textContent).to.contain(`Expand all blocks`);
    }
  });

  test(`says what it does in words`, async () => {
    await act(() => render(<BlocksToggle pipelines={[p]} anchor={null}/>, root));
    expect(button().tagName).to.equal(`BUTTON`);
    expect(button().textContent).to.contain(`Expand all blocks`);
    expect(button().dataset.tippyContent).to.equal(`Expands the blocks of every open pipeline`);

    await click();
    expect(button().textContent).to.contain(`Collapse all blocks`);
    expect(button().dataset.tippyContent).to.equal(`Collapses the blocks of every open pipeline`);
  });

  test(`opens every block of the open pipelines, then closes them again, and leaves other pipelines' blocks alone`, async () => {
    openBlocks.value = new Set([`p/test`, closed.id]);
    await act(() => render(<BlocksToggle pipelines={[p, q]} anchor={null}/>, root));
    expect(button().disabled).to.equal(false);

    await click();
    expect([...openBlocks.value].sort()).to.deep.equal([`p/build`, `p/lint`, `p/test`, `q/deploy`, closed.id].sort());

    await click();
    expect([...openBlocks.value]).to.deep.equal([closed.id]);
  });

  test(`offers to expand as long as one block of an open pipeline is closed`, async () => {
    openBlocks.value = new Set([`p/lint`, `p/test`, `p/build`]);
    await act(() => render(<BlocksToggle pipelines={[p, q]} anchor={null}/>, root));
    expect(button().textContent).to.contain(`Expand all blocks`);

    await click();
    expect([...openBlocks.value].sort()).to.deep.equal([`p/build`, `p/lint`, `p/test`, `q/deploy`]);
    expect(button().textContent).to.contain(`Collapse all blocks`);
  });
});
