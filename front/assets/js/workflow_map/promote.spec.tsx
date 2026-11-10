import { expect } from "chai";
import { afterEach, beforeEach, describe, test } from "mocha";
import { render } from "preact";
import { act } from "preact/test-utils";

import { Pipeline, Promotion } from "./model";
import { PromoteButton, PromoteDialog, promoting } from "./promote";

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
