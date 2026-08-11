import { expect } from "chai";
import { tooltipTargets } from "./tippy";

describe(`tooltipTargets`, () => {
  beforeEach(() => {
    document.body.innerHTML = ``;
  });

  it(`collects elements asking for a tooltip`, () => {
    document.body.innerHTML = `
      <div id="block">
        <a data-tippy-content="one">a</a>
        <a>b</a>
        <a data-tippy-content="two">c</a>
      </div>
    `;

    expect(tooltipTargets(document).length).to.equal(2);
  });

  it(`skips elements that already have an instance`, () => {
    document.body.innerHTML = `
      <a id="fresh" data-tippy-content="one">a</a>
      <a id="bound" data-tippy-content="two">b</a>
    `;

    (document.getElementById(`bound`) as any)._tippy = { destroy: () => undefined };

    const targets = tooltipTargets(document);

    expect(targets.length).to.equal(1);
    expect((targets[0] as HTMLElement).id).to.equal(`fresh`);
  });

  it(`scopes to the given root`, () => {
    document.body.innerHTML = `
      <div id="left"><a data-tippy-content="one">a</a></div>
      <div id="right"><a data-tippy-content="two">b</a></div>
    `;

    const left = document.getElementById(`left`);

    expect(tooltipTargets(left).length).to.equal(1);
  });

  it(`includes the root itself when it asks for a tooltip`, () => {
    document.body.innerHTML = `<a id="row" data-tippy-content="one"><span>a</span></a>`;

    const row = document.getElementById(`row`);

    expect(tooltipTargets(row).length).to.equal(1);
  });

  it(`returns nothing for a root that cannot be queried`, () => {
    expect(tooltipTargets(document.createTextNode(`text`) as any).length).to.equal(0);
  });
});
