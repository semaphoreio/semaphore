import { expect } from "chai";
import { afterEach, beforeEach, describe, test } from "mocha";
import { render } from "preact";
import { act } from "preact/test-utils";

import { Pipeline, Promotion } from "./model";
import { PromoteDialog, promoting } from "./promote";

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
