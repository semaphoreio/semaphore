import "../spec_dom";
import { expect } from "chai";
import { afterEach, describe, test } from "mocha";
import { render } from "preact";
import { act } from "preact/test-utils";
import { TierSelector } from "./tier_selector";
import * as types from "../types";

const group = (json: Record<string, unknown>): types.Addons.AddonGroup =>
  types.Addons.AddonGroup.fromJSON({
    name: `support`,
    display_name: `Support Plans`,
    type: `exclusive`,
    disabling_is_final: false,
    on_cooldown: false,
    ...json,
  });

const addon = (name: string, json: Record<string, unknown>) => ({
  name,
  display_name: name,
  price: `$50.00/mo`,
  enabled: false,
  modifiable: true,
  self_service: true,
  ...json,
});

describe(`TierSelector`, () => {
  let root: HTMLElement;

  const mount = async (g: types.Addons.AddonGroup) => {
    root = document.body.appendChild(document.createElement(`div`));
    await act(() => {
      render(<TierSelector group={g} updating={null} onUpdate={() => undefined}/>, root);
    });
  };

  const radio = (label: string) =>
    Array.from(root.querySelectorAll(`label`))
      .find((l) => l.textContent.includes(label))
      .querySelector(`input`);

  const choose = (label: string) => act(() => { radio(label).click(); });

  afterEach(() => {
    render(null, root);
    root.remove();
  });

  test(`an unpriced current tier is not shown as locked and a priced tier stays selectable`, async () => {
    await mount(group({
      addons: [
        addon(`Custom`, { price: ``, enabled: true, modifiable: false, self_service: false }),
        addon(`Priority`, {}),
        addon(`Premium`, { price: ``, self_service: false, modifiable: false }),
        addon(`Metered`, { price: `` }),
      ],
    }));

    expect(root.textContent).to.not.contain(`Selection locked`);
    expect(radio(`Priority`).disabled).to.eq(false);
    expect(radio(`Metered`).disabled).to.eq(false);
    expect(radio(`Premium`).disabled).to.eq(true);
    expect(root.textContent.match(/Contact support to switch to this tier/g)).to.have.length(1);
  });

  test(`warns that disabling lasts 24 hours when billing says it is not final`, async () => {
    await mount(group({ addons: [addon(`Basic`, { enabled: true }), addon(`Priority`, {})] }));
    await choose(`No support add-on selected`);

    expect(root.textContent).to.contain(`for the next 24 hours`);
    expect(root.textContent).to.not.contain(`contact support to enable it again`);
  });

  test(`warns that support is needed when billing says disabling is final`, async () => {
    await mount(group({ disabling_is_final: true, addons: [addon(`Basic`, { enabled: true }), addon(`Priority`, {})] }));
    await choose(`No support add-on selected`);

    expect(root.textContent).to.contain(`You will need to contact support to enable it again.`);
    expect(root.textContent).to.not.contain(`for the next 24 hours`);
  });

  test(`explains the cooldown when a tier is selected`, async () => {
    await mount(group({
      on_cooldown: true,
      addons: [addon(`Basic`, { enabled: true, modifiable: false }), addon(`Priority`, { modifiable: false })],
    }));

    expect(root.textContent).to.contain(`Selection locked for 24 hours. You can still disable the current add-on.`);
    expect(radio(`Priority`).disabled).to.eq(true);
  });

  test(`explains the cooldown when nothing is selected`, async () => {
    await mount(group({
      on_cooldown: true,
      addons: [addon(`Basic`, { modifiable: false }), addon(`Priority`, { modifiable: false })],
    }));

    expect(root.textContent).to.contain(`Selection locked for 24 hours.`);
    expect(root.textContent).to.not.contain(`You can still disable`);
    expect(radio(`Basic`).disabled).to.eq(true);
    expect(radio(`Priority`).disabled).to.eq(true);
  });
});
