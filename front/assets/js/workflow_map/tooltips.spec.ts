import { expect } from "chai";
import { bindTooltips } from "./tooltips";

interface Fake { props: { content: string, }, setContent: (c: string) => void, destroy: () => void, reference: Element, }

const factory = (made: Fake[]) => (node: HTMLElement) => {
  const tip: Fake = {
    props: { content: node.dataset.tippyContent },
    setContent: (c) => (tip.props.content = c),
    destroy: () => undefined,
    reference: node,
  };
  (node as unknown as { _tippy: Fake, })._tippy = tip;
  made.push(tip);
  return tip;
};

describe(`bindTooltips`, () => {
  beforeEach(() => {
    document.body.innerHTML = `<div id="root"><button id="a" data-tippy-content="one">a</button><button id="b">b</button></div>`;
  });

  it(`binds only the elements that ask for a tooltip`, () => {
    const made: Fake[] = [];
    bindTooltips(document.getElementById(`root`), factory(made));
    expect(made).to.have.length(1);
    expect(made[0].reference.id).to.equal(`a`);
  });

  it(`does not bind twice, and follows a changed tooltip`, () => {
    const made: Fake[] = [];
    const root = document.getElementById(`root`);
    bindTooltips(root, factory(made));
    document.getElementById(`a`).dataset.tippyContent = `two`;
    bindTooltips(root, factory(made));
    expect(made).to.have.length(1);
    expect(made[0].props.content).to.equal(`two`);
  });

  it(`binds elements rendered later`, () => {
    const made: Fake[] = [];
    const root = document.getElementById(`root`);
    bindTooltips(root, factory(made));
    document.getElementById(`b`).dataset.tippyContent = `late`;
    bindTooltips(root, factory(made));
    expect(made).to.have.length(2);
  });

  it(`destroys the tooltip of an element that left the page`, () => {
    let destroyed = 0;
    const gone = document.createElement(`button`);
    const popper = document.createElement(`div`);
    popper.setAttribute(`data-tippy-root`, ``);
    (popper as unknown as { _tippy: unknown, })._tippy = { reference: gone, destroy: () => destroyed++ };
    document.body.append(popper);
    bindTooltips(document.getElementById(`root`), factory([]));
    expect(destroyed).to.equal(1);
  });

  it(`does nothing without tippy`, () => {
    expect(() => bindTooltips(document.getElementById(`root`), undefined)).to.not.throw();
  });
});
