import { expect } from "chai";
import { afterEach, before, beforeEach, describe, test } from "mocha";
import { render } from "preact";
import { act } from "preact/test-utils";

import { defineTimeAgoElement } from "../time_ago";
import { ApiTriggerer, Block, Job, Pipeline } from "./model";
import { now } from "./store";
import { BlockCard, BlockSummary, DOUBLE_CLICK_MS, JobRow, PipelineTitle, TimeAgo, Triggered } from "./ui";

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

    expect(root.querySelector(`.wf-map-block-head`).hasAttribute(`data-tippy-content`)).to.equal(false);
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
  describe(`a click on a node acts only when it selects no text`, () => {
    const block = { id: `b`, name: `a very long block name`, deps: [], jobs: [] } as Block;
    const wait = () => new Promise((r) => setTimeout(r, DOUBLE_CLICK_MS + 20));
    const click = (el: Element, init: MouseEventInit = {}) => {
      el.dispatchEvent(new MouseEvent(`pointerdown`, { bubbles: true, clientX: 10, clientY: 10 }));
      return el.dispatchEvent(new MouseEvent(`click`, { bubbles: true, cancelable: true, detail: 1, clientX: 10, clientY: 10, ...init }));
    };
    let toggled: number;

    beforeEach(async () => {
      toggled = 0;
      await act(() => render(<BlockSummary block={block} onClick={() => toggled++}/>, root));
    });

    test(`a plain click outside the name acts at once`, () => {
      click(root.querySelector(`.wf-map-summary-meta`));
      expect(toggled).to.equal(1);
    });

    test(`a plain click on the name acts after the double-click interval`, async () => {
      click(root.querySelector(`.wf-map-name-text`));
      expect(toggled).to.equal(0);
      await wait();
      expect(toggled).to.equal(1);
    });

    test(`a double or triple click on the name never acts`, async () => {
      const name = root.querySelector(`.wf-map-name-text`);
      click(name);
      click(name, { detail: 2 });
      click(name, { detail: 3 });
      await wait();
      expect(toggled).to.equal(0);
    });

    test(`a keyboard click acts at once, wherever the pointer was`, () => {
      root.querySelector(`.wf-map-name-text`).dispatchEvent(new MouseEvent(`pointerdown`, { bubbles: true, clientX: 300, clientY: 300 }));
      root.querySelector(`.wf-map-summary`).dispatchEvent(new MouseEvent(`click`, { bubbles: true, detail: 0 }));
      expect(toggled).to.equal(1);
    });

    test(`a click on another node does not cancel a pending click on a name`, async () => {
      const other = { id: `c`, name: `another block`, deps: [], jobs: [] } as Block;
      let otherToggled = 0;
      const box = document.createElement(`div`);
      root.appendChild(box);
      await act(() => render(<BlockSummary block={other} onClick={() => otherToggled++}/>, box));

      click(root.querySelector(`.wf-map-name-text`));
      click(box.querySelector(`.wf-map-summary-meta`));
      await wait();
      expect([toggled, otherToggled]).to.deep.equal([1, 1]);
      render(null, box);
    });

    test(`a drag that ends on the node never acts, even when it selected nothing`, async () => {
      click(root.querySelector(`.wf-map-name-text`), { clientX: 60 });
      await wait();
      expect(toggled).to.equal(0);
    });

    test(`a job row keeps a modifier click for the browser and swallows a selecting click`, async () => {
      const job = { key: `b#0`, id: `j1`, name: `a very long job name`, status: `passed`, startedAt: null, finishedAt: null, reused: false } as Job;
      await act(() => render(<JobRow job={job}/>, root));
      const row = root.querySelector(`.wf-map-job`);

      expect(click(row, { metaKey: true })).to.equal(true);
      window.getSelection().selectAllChildren(root.querySelector(`.wf-map-name-text`));
      expect(click(row)).to.equal(false);
      window.getSelection().removeAllRanges();
    });
  });
  describe(`the copy button on a name`, () => {
    let copied: string[];
    const realClipboard = Object.getOwnPropertyDescriptor(navigator, `clipboard`);

    beforeEach(() => {
      copied = [];
      Object.defineProperty(navigator, `clipboard`, { configurable: true, value: { writeText: (t: string) => (copied.push(t), Promise.resolve()) } });
    });

    afterEach(() => {
      if (realClipboard) Object.defineProperty(navigator, `clipboard`, realClipboard);
      else delete (navigator as { clipboard?: unknown, }).clipboard;
    });

    test(`copies the full name, says so, and never toggles the block`, async () => {
      const block = { id: `b`, name: `a very long block name`, deps: [], jobs: [] } as Block;
      let toggled = 0;
      await act(() => render(<BlockSummary block={block} onClick={() => toggled++}/>, root));

      await act(async () => {
        root.querySelector(`.wf-map-copy`).dispatchEvent(new MouseEvent(`click`, { bubbles: true, cancelable: true, detail: 1 }));
        await Promise.resolve();
      });
      await new Promise((r) => setTimeout(r, DOUBLE_CLICK_MS + 20));

      expect(copied).to.deep.equal([block.name]);
      expect(toggled).to.equal(0);
      expect(root.querySelector(`.wf-map-copy`).classList.contains(`copied`)).to.equal(true);
      expect(root.querySelector(`.wf-map-copy`).getAttribute(`aria-label`)).to.equal(`Copied`);
      expect(root.querySelector(`.wf-map-name`).textContent).to.equal(block.name);
    });

    test(`in a job row it keeps the browser from opening the job`, async () => {
      const job = { key: `b#0`, id: `j1`, name: `a very long job name`, status: `passed`, startedAt: null, finishedAt: null, reused: false } as Job;
      await act(() => render(<JobRow job={job}/>, root));

      const opened = root.querySelector(`.wf-map-copy`).dispatchEvent(new MouseEvent(`click`, { bubbles: true, cancelable: true, detail: 1 }));

      expect(opened).to.equal(false);
      expect(copied).to.deep.equal([job.name]);
    });
  });
  describe(`collapsing and expanding`, () => {
    const job = { key: `b#0`, id: null, name: `lint`, status: `passed`, startedAt: null, finishedAt: null, reused: false } as Job;
    const block = { id: `b`, name: `Lint`, deps: [], jobs: [job] } as Block;

    test(`a collapsed block says it is collapsed and shows a closed chevron`, async () => {
      await act(() => render(<BlockSummary block={block} onClick={() => undefined}/>, root));
      expect(root.querySelector(`.wf-map-summary`).getAttribute(`aria-expanded`)).to.equal(`false`);
      expect(root.querySelector(`.wf-map-summary .wf-map-chevron`).classList.contains(`open`)).to.equal(false);
    });

    test(`an open block's head says it is expanded, shows an open chevron and has no tooltip`, async () => {
      await act(() => render(<BlockCard block={block} onHeaderClick={() => undefined}/>, root));
      const head = root.querySelector(`.wf-map-block-head`);
      expect(head.getAttribute(`aria-expanded`)).to.equal(`true`);
      expect(head.querySelector(`.wf-map-chevron`).classList.contains(`open`)).to.equal(true);
      expect(head.hasAttribute(`data-tippy-content`)).to.equal(false);
      expect(head.querySelector(`.wf-map-chevron`).getAttribute(`aria-hidden`)).to.equal(`true`);
    });
  });
});

describe(`how and when a pipeline was triggered`, () => {
  let root: HTMLElement;
  const triggerer = (over: Partial<ApiTriggerer> = {}): ApiTriggerer => ({ text: `Manual promotion`, link: null, owner: `Ana Kowalska`, stopped: false, stopped_by: null, ...over });
  const show = (t: ApiTriggerer, createdAt: number | null = 1700000000, trigger = `MANUAL_PROMOTION`) => act(() => render(<Triggered p={{ triggerer: t, createdAt, trigger } as Pipeline}/>, root));
  const shown = () => root.querySelector<HTMLElement>(`.wf-map-triggered`);
  const icon = () => shown().querySelector(`.material-symbols-outlined`);
  const text = () => shown().textContent.replace(icon().textContent, ``);
  const tip = () => shown().dataset.tippyContent;

  before(() => {
    globalThis.customElements = document.defaultView.customElements;
    defineTimeAgoElement();
  });

  beforeEach(() => {
    root = document.createElement(`div`);
    document.body.appendChild(root);
    now.value = 1700000000 + 4 * 86400 + 5;
  });

  afterEach(() => {
    render(null, root);
    root.remove();
  });

  test(`shows an icon for how and a short time for when, with how, who and the exact time on hover`, async () => {
    await show(triggerer());
    expect(icon().textContent).to.equal(`person`);
    expect(icon().getAttribute(`aria-hidden`)).to.equal(`true`);
    expect(text()).to.equal(`4d ago`);
    expect(tip()).to.match(/^Manual promotion by Ana Kowalska · .*2023/);
    expect(shown().getAttribute(`aria-label`)).to.equal(tip());
  });

  test(`follows the map's clock`, async () => {
    await show(triggerer());
    await act(() => {
      now.value = 1700000000 + 5 * 86400;
    });
    expect(text()).to.equal(`5d ago`);
  });

  test(`has an icon for every trigger type, and one for a type it does not know`, async () => {
    const icons: string[] = [];
    for (const trigger of [`INITIAL_WORKFLOW`, `WORKFLOW_RERUN`, `API`, `SCHEDULED_RUN`, `SCHEDULED_MANUAL_RUN`, `PIPELINE_PARTIAL_RERUN`, `MANUAL_PROMOTION`, `AUTO_PROMOTION`, `SOMETHING_NEW`]) {
      await show(triggerer({ text: `Server text`, owner: null }), 1700000000, trigger);
      icons.push(icon().textContent);
    }
    expect(icons).to.deep.equal([`commit`, `replay`, `api`, `schedule`, `play_arrow`, `replay`, `person`, `bolt`, `play_arrow`]);
  });

  test(`says nothing about who when the pipeline has no owner`, async () => {
    await show(triggerer({ text: `Auto promoted`, owner: null }), 1700000000, `AUTO_PROMOTION`);
    expect(tip()).to.match(/^Auto promoted · /);
  });

  test(`links what it was a rerun of, and the link does not open the pipeline`, async () => {
    let opened = 0;
    root.addEventListener(`click`, () => opened++);
    await show(triggerer({ text: `Triggered by rerun of a`, link: { label: `Workflow`, url: `/workflows/w1` } }), 1700000000, `WORKFLOW_RERUN`);
    expect(tip()).to.match(/^Triggered by rerun of a Workflow by Ana Kowalska · /);
    expect(shown().tagName).to.equal(`A`);
    expect(shown().getAttribute(`href`)).to.equal(`/workflows/w1`);
    shown().addEventListener(`click`, (e) => e.preventDefault());
    shown().click();
    expect(opened).to.equal(0);
    await show(triggerer());
    expect(shown().tagName).to.equal(`SPAN`);
  });

  test(`says on hover who stopped it, or only that it was stopped`, async () => {
    await show(triggerer({ text: `Triggered by push`, stopped: true, stopped_by: `Bo Svensson` }), 1700000000, `INITIAL_WORKFLOW`);
    expect(tip()).to.match(/^Triggered by push by Ana Kowalska · .* · Stopped by Bo Svensson$/);
    await show(triggerer({ text: `Triggered by push`, stopped: true }), 1700000000, `INITIAL_WORKFLOW`);
    expect(tip()).to.match(/ · Stopped$/);
    await show(triggerer({ text: `Triggered by push` }), 1700000000, `INITIAL_WORKFLOW`);
    expect(tip()).to.not.contain(`Stopped`);
  });

  test(`shows nothing when the map data has no triggerer`, async () => {
    await show(undefined);
    expect(shown()).to.equal(null);
  });

  test(`shows only the icon before the pipeline has a time`, async () => {
    await show(triggerer(), null);
    expect(text()).to.equal(``);
    expect(tip()).to.equal(`Manual promotion by Ana Kowalska`);
  });

  test(`a new time replaces the time-ago element, which reads its time only once`, async () => {
    const time = () => root.querySelector<HTMLElement & { datetime: string, }>(`time-ago`);
    await act(() => render(<TimeAgo at={1700000000}/>, root));
    const first = time();
    await act(() => render(<TimeAgo at={1700000000}/>, root));
    expect(time()).to.equal(first);
    await act(() => render(<TimeAgo at={1700003600}/>, root));
    expect(time()).to.not.equal(first);
    expect(time().datetime).to.equal(`2023-11-14T23:13:20.000Z`);
  });
});
