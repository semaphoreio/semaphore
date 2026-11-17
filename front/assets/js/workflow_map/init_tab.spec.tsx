import { expect } from "chai";
import { afterEach, beforeEach, describe, test } from "mocha";
import { render } from "preact";
import { act } from "preact/test-utils";

import { InitTab } from "./map";
import { InitJob } from "./model";
import { now } from "./store";

describe(`the init job's tab under a pipeline's header`, () => {
  let root: HTMLElement;
  const show = (job: InitJob) => act(() => render(<InitTab job={job}/>, root));
  const tab = () => root.querySelector<HTMLAnchorElement>(`.wf-map-init-tab`);

  beforeEach(() => {
    root = document.createElement(`div`);
    document.body.appendChild(root);
  });

  afterEach(() => {
    render(null, root);
    root.remove();
  });

  test(`shows the status, the name and how long the init job took, and opens its log without selecting the pipeline`, async () => {
    let selected = 0;
    root.addEventListener(`click`, () => selected++);
    await show({ url: `/jobs/init-1`, status: `passed`, started_at: 1700000000, finished_at: 1700000007 });
    expect(tab().getAttribute(`href`)).to.equal(`/jobs/init-1`);
    expect(tab().querySelector(`.wf-map-icon`).getAttribute(`aria-label`)).to.equal(`Passed`);
    expect(tab().textContent).to.equal(`Init00:07`);
    expect(tab().dataset.tippyContent).to.equal(`Opens the initialization log`);
    tab().addEventListener(`click`, (e) => e.preventDefault());
    tab().click();
    expect(selected).to.equal(0);
  });

  test(`counts up while the init job runs, and shows no time before it has started`, async () => {
    now.value = 1700000012;
    await show({ url: `/jobs/init-1`, status: `running`, started_at: 1700000000, finished_at: null });
    expect(tab().textContent).to.equal(`Init00:12`);
    await show({ url: `/jobs/init-1`, status: `pending`, started_at: null, finished_at: null });
    expect(tab().textContent).to.equal(`Init--:--`);
  });
});
