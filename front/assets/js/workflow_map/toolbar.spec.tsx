import { expect } from "chai";
import { afterEach, beforeEach, describe, test } from "mocha";
import { render } from "preact";
import { act } from "preact/test-utils";
import { install, uninstall } from "@github/hotkey";

import { Search } from "./toolbar";

describe(`map search hotkey`, () => {
  let root: HTMLElement;
  let menu: HTMLElement;
  let menuClicks: number;

  const slash = () => document.body.dispatchEvent(new KeyboardEvent(`keydown`, { key: `/`, bubbles: true, cancelable: true }));

  beforeEach(() => {
    menuClicks = 0;
    menu = document.createElement(`div`);
    menu.setAttribute(`data-hotkey`, `/`);
    menu.addEventListener(`click`, () => menuClicks++);
    document.body.appendChild(menu);
    install(menu);
    root = document.createElement(`div`);
    document.body.appendChild(root);
  });

  afterEach(() => {
    render(null, root);
    root.remove();
    uninstall(menu);
    menu.remove();
  });

  test(`"/" focuses the map search and leaves the page's own "/" hotkey alone`, async () => {
    await act(() => render(<Search/>, root));

    slash();

    expect(document.activeElement).to.equal(root.querySelector(`input`));
    expect(menuClicks).to.equal(0);
  });

  test(`the page's "/" hotkey works again once the map search is gone`, async () => {
    await act(() => render(<Search/>, root));
    await act(() => render(null, root));

    slash();

    expect(menuClicks).to.equal(1);
  });
});
