import { expect } from "chai";
import { afterEach, beforeEach, describe, test } from "mocha";
import { render } from "preact";
import { act } from "preact/test-utils";

import { Pipeline, Promotion } from "./model";
import { PromoteButton, PromoteDialog, Promotions, promoting } from "./promote";
import { popover } from "./store";

describe(`promote dialog`, () => {
  const realFetch = globalThis.fetch;
  let root: HTMLElement;
  let posted: unknown[];

  const param = (name: string, options: string[], default_value: string, required = false) => ({ name, options, default_value, required, description: `` });

  const open = (parameters: ReturnType<typeof param>[]) =>
    act(() => {
      promoting.value = {
        pipeline: { id: `ci`, name: `Build & test` } as Pipeline,
        promotion: { name: `Production`, trigger_url: `/promote`, parameters } as unknown as Promotion,
      };
      render(<PromoteDialog/>, root);
    });

  const submit = () =>
    act(async () => {
      root.querySelector(`form`).dispatchEvent(new Event(`submit`, { cancelable: true }));
      await new Promise((r) => setTimeout(r, 0));
    });

  beforeEach(() => {
    root = document.createElement(`div`);
    document.body.appendChild(root);
    posted = [];
    globalThis.fetch = ((_url: string, init: RequestInit) => {
      posted.push(JSON.parse(init.body as string));
      return Promise.resolve(new Response(`{}`, { status: 200 }));
    }) as typeof fetch;
  });

  afterEach(() => {
    render(null, root);
    root.remove();
    promoting.value = null;
    globalThis.fetch = realFetch;
  });

  test(`leaves out an optional choice nobody picked and keeps defaults and text`, async () => {
    await open([param(`env`, [`staging`, `prod`], ``), param(`region`, [`eu`, `us`], `eu`), param(`note`, [], ``)]);

    const env = root.querySelector<HTMLSelectElement>(`#wf-map-param-env`);
    expect(env.value).to.eq(``);
    expect(env.options[0].textContent).to.eq(`Select an option`);
    expect(env.options[0].disabled).to.eq(true);
    expect([...env.options].map((o) => o.value)).to.deep.eq([``, `staging`, `prod`]);

    await submit();

    expect(posted).to.deep.eq([{ parameters: { region: `eu`, note: `` } }]);
  });

  test(`asks for a required choice before sending anything`, async () => {
    await open([param(`env`, [`staging`, `prod`], ``, true)]);

    await submit();

    expect(posted).to.deep.eq([]);
    expect(root.querySelector(`.wf-map-dialog-error`).textContent).to.eq(`Fill in env first.`);
  });
});

describe(`promote button`, () => {
  let root: HTMLElement;

  beforeEach(() => {
    root = document.createElement(`div`);
    document.body.appendChild(root);
  });

  afterEach(() => {
    render(null, root);
    root.remove();
  });

  const promotion = (name: string, runs: number) => ({ name, events: Array.from({ length: runs }, () => ({})) }) as unknown as Promotion;

  test(`counts the promotions the pipeline defines, whether they ran or not`, async () => {
    for (const [promotions, count, tip] of [
      [[promotion(`Staging`, 2), promotion(`Production`, 0), promotion(`Canary`, 0)], `3`, `Promote: 3 promotions`],
      [[promotion(`Staging`, 1), promotion(`Production`, 1)], `2`, `Promote: 2 promotions`],
      [[promotion(`Production`, 0)], `1`, `Promote: 1 promotion`],
    ] as const) {
      await act(() => render(<PromoteButton p={{ id: `ci`, name: `Build`, promotions } as unknown as Pipeline}/>, root));
      expect(root.querySelector(`.wf-map-promote-count`).textContent).to.equal(count);
      expect(root.querySelector<HTMLElement>(`.wf-map-promote`).dataset.tippyContent).to.equal(tip);
    }
  });

  test(`is not there without promotions`, async () => {
    await act(() => render(<PromoteButton p={{ id: `ci`, name: `Build`, promotions: [] } as unknown as Pipeline}/>, root));
    expect(root.querySelector(`.wf-map-promote`)).to.equal(null);
  });
});

describe(`promotions menu filter`, () => {
  let root: HTMLElement;
  let closeOnEscape: (e: KeyboardEvent) => void;
  const promotion = (name: string) => ({ name, events: [], can_promote: true, parameters: [] }) as unknown as Promotion;
  const p = { id: `ci`, name: `Build`, promotions: [promotion(`Staging`), promotion(`Production EU`), promotion(`Production US`), promotion(`Canary`)] } as unknown as Pipeline;
  const names = () => [...root.querySelectorAll(`.wf-map-promotion-name`)].map((n) => n.textContent);
  const filter = () => root.querySelector<HTMLInputElement>(`.wf-map-promotion-filter`);
  const type = (text: string) =>
    act(() => {
      filter().value = text;
      filter().dispatchEvent(new Event(`input`, { bubbles: true }));
    });
  const press = (key: string) =>
    act(() => {
      filter().dispatchEvent(new KeyboardEvent(`keydown`, { key, bubbles: true, cancelable: true }));
    });

  beforeEach(async () => {
    root = document.createElement(`div`);
    document.body.appendChild(root);
    popover.value = { kind: `promote`, id: `ci`, x: 0, y: 0 } as typeof popover.value;
    closeOnEscape = (e) => e.key === `Escape` && (popover.value = null);
    document.addEventListener(`keydown`, closeOnEscape);
    await act(() => render(<Promotions p={p}/>, root));
  });

  afterEach(() => {
    document.removeEventListener(`keydown`, closeOnEscape);
    render(null, root);
    root.remove();
    popover.value = null;
    promoting.value = null;
  });

  test(`is focused when the menu opens and lists every promotion`, () => {
    expect(document.activeElement).to.equal(filter());
    expect(names()).to.deep.equal([`Staging`, `Production EU`, `Production US`, `Canary`]);
  });

  test(`narrows the list by name, ignoring case`, async () => {
    await type(`  prod `);
    expect(names()).to.deep.equal([`Production EU`, `Production US`]);
    await type(`US`);
    expect(names()).to.deep.equal([`Production US`]);
  });

  test(`says so when nothing matches`, async () => {
    await type(`nightly`);
    expect(names()).to.deep.equal([]);
    expect(root.querySelector(`.wf-map-promotion-none`).textContent).to.equal(`No promotion matches “nightly”`);
  });

  test(`clears on the first Escape and closes the menu on the second`, async () => {
    await type(`can`);
    await press(`Escape`);
    expect(filter().value).to.equal(``);
    expect(names()).to.have.length(4);
    expect(popover.value).to.not.equal(null);
    await press(`Escape`);
    expect(popover.value).to.equal(null);
  });

  test(`does not promote on Enter`, async () => {
    await type(`Canary`);
    await press(`Enter`);
    expect(promoting.value).to.equal(null);
    expect(popover.value).to.not.equal(null);
  });
});
