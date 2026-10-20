import "../spec_dom";
import { expect } from "chai";
import { afterEach, beforeEach, describe, test } from "mocha";
import { render } from "preact";
import { act } from "preact/test-utils";
import { AddonsPage } from "./addons_page";
import * as stores from "../stores";

const reason = `This tier is not available for self-service. Contact support to change it.`;

const groups = {
  groups: [
    {
      name: `support`,
      display_name: `Support Plans`,
      type: `exclusive`,
      disabling_is_final: false,
      on_cooldown: false,
      addons: [
        { name: `support-tier-1`, display_name: `Basic`, price: `$50.00/mo`, enabled: false, modifiable: true, self_service: true },
      ],
    },
  ],
};

const respond = (body: unknown) => Promise.resolve({ json: () => Promise.resolve(body) });

const flush = () => act(async () => {
  await new Promise((resolve) => setTimeout(resolve, 0));
});

describe(`AddonsPage`, () => {
  let root: HTMLElement;
  let originalFetch: typeof globalThis.fetch;

  beforeEach(() => {
    originalFetch = globalThis.fetch;
    root = document.body.appendChild(document.createElement(`div`));
  });

  afterEach(() => {
    render(null, root);
    root.remove();
    globalThis.fetch = originalFetch;
  });

  test(`shows the reason billing gives for refusing an update`, async () => {
    globalThis.fetch = ((_url: string, init?: RequestInit) =>
      init?.method === `POST` ? respond({ ok: false, error: reason }) : respond(groups)) as any;

    const config = {
      addonsUrl: `http://localhost/billing/addons.json`,
      updateAddonUrl: `http://localhost/billing/update_addon.json`,
    } as stores.Config.State;

    await act(() => {
      render(<stores.Config.Context.Provider value={config}><AddonsPage/></stores.Config.Context.Provider>, root);
    });
    await flush();

    const basic = Array.from(root.querySelectorAll(`label`))
      .find((l) => l.textContent.includes(`Basic`))
      .querySelector(`input`);
    await act(() => { basic.click(); });

    const save = Array.from(root.querySelectorAll(`button`)).find((b) => b.textContent === `Save`);
    await act(() => { save.click(); });
    await flush();

    expect(root.textContent).to.contain(reason);
  });
});
