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
  const other = block(`q`, `deploy`);

  beforeEach(() => {
    root = document.createElement(`div`);
    document.body.appendChild(root);
  });

  afterEach(() => {
    render(null, root);
    root.remove();
    openBlocks.value = new Set();
  });

  const click = async () => {
    await act(() => {
      root.querySelector(`.wf-map-blocks-toggle`).dispatchEvent(new MouseEvent(`click`, { bubbles: true }));
    });
  };

  test(`is not shown while blocks load or for a pipeline with fewer than two blocks`, async () => {
    for (const q of [pipeline(`a`, null), pipeline(`b`, []), pipeline(`c`, [block(`c`, `only`)])]) {
      await act(() => render(<BlocksToggle p={q} at={{ x: 0, y: 0 }}/>, root));
      expect(root.querySelector(`.wf-map-blocks-toggle`)).to.equal(null);
    }
  });

  test(`opens every block of its pipeline, then closes them again, and leaves other pipelines' blocks alone`, async () => {
    openBlocks.value = new Set([`p/test`, other.id]);
    await act(() => render(<BlocksToggle p={p} at={{ x: 0, y: 0 }}/>, root));
    const button = root.querySelector<HTMLButtonElement>(`.wf-map-blocks-toggle`);
    expect(button.tagName).to.equal(`BUTTON`);
    expect(button.getAttribute(`aria-label`)).to.equal(`Expand all blocks of Pipeline p`);
    expect(button.dataset.tippyContent).to.equal(`Expand all blocks`);

    await click();
    expect([...openBlocks.value].sort()).to.deep.equal([`p/build`, `p/lint`, `p/test`, other.id].sort());
    expect(button.getAttribute(`aria-label`)).to.equal(`Collapse all blocks of Pipeline p`);
    expect(button.dataset.tippyContent).to.equal(`Collapse all blocks`);

    await click();
    expect([...openBlocks.value]).to.deep.equal([other.id]);
    expect(button.getAttribute(`aria-label`)).to.equal(`Expand all blocks of Pipeline p`);
  });

  test(`does not pass the click on to the pipeline`, async () => {
    let reached = 0;
    await act(() =>
      render(
        <div onClick={() => reached++}>
          <BlocksToggle p={p} at={{ x: 0, y: 0 }}/>
        </div>,
        root,
      ),
    );
    await click();
    expect(reached).to.equal(0);
  });
});
