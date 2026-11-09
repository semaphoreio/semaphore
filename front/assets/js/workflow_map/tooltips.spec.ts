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

  it(`gives the map's tooltips their own theme`, () => {
    const props: { duration: unknown, theme: unknown, }[] = [];
    bindTooltips(document.getElementById(`root`), (node: HTMLElement, p: { duration: unknown, theme: unknown, }) => props.push(p) && factory([])(node));
    expect(props.map(({ duration, theme }) => ({ duration, theme }))).to.deep.equal([{ duration: [150, 50], theme: `wf-map` }]);
  });

  describe(`a name's tooltip shows only when the name is cut`, () => {
    const size = (node: HTMLElement, box: { scrollWidth: number, clientWidth: number, scrollHeight: number, clientHeight: number, }) =>
      Object.entries(box).forEach(([k, v]) => Object.defineProperty(node, k, { value: v }));
    const onShowFor = (html: string) => {
      document.body.innerHTML = `<div id="root">${html}</div>`;
      let onShow: (tip: { reference: Element, }) => boolean;
      bindTooltips(document.getElementById(`root`), (node: HTMLElement, p: { onShow: typeof onShow, }) => (onShow = p.onShow) && factory([])(node));
      return (box: Parameters<typeof size>[1]) => {
        const node = document.getElementById(`n`);
        size(node, box);
        return onShow({ reference: node });
      };
    };
    const fits = { scrollWidth: 80, clientWidth: 80, scrollHeight: 32, clientHeight: 32 };

    it(`stays hidden for a name that fits`, () => {
      expect(onShowFor(`<span id="n" data-tippy-content="lint" data-tip-if-cut>lint</span>`)(fits)).to.equal(false);
    });

    it(`shows for a name cut on one line`, () => {
      expect(onShowFor(`<span id="n" data-tippy-content="long" data-tip-if-cut>long</span>`)({ ...fits, scrollWidth: 140 })).to.equal(true);
    });

    it(`shows for a name cut after two lines`, () => {
      expect(onShowFor(`<span id="n" data-tippy-content="long" data-tip-if-cut>long</span>`)({ ...fits, scrollHeight: 48 })).to.equal(true);
    });

    it(`stays hidden for a name that overflows its line box by 1 px`, () => {
      const show = (box: Partial<typeof fits>) => onShowFor(`<span id="n" data-tippy-content="After pipeline" data-tip-if-cut>After pipeline</span>`)({ ...fits, ...box });
      expect(show({ scrollHeight: 19, clientHeight: 18 })).to.equal(false);
      expect(show({ scrollWidth: 95, clientWidth: 94 })).to.equal(false);
    });

    it(`shows for a two-line name cut by more than 1 px`, () => {
      const show = (box: Partial<typeof fits>) => onShowFor(`<span id="n" data-tippy-content="long" data-tip-if-cut>long</span>`)({ ...fits, ...box });
      expect(show({ scrollHeight: 55, clientHeight: 36 })).to.equal(true);
      expect(show({ scrollWidth: 96, clientWidth: 94 })).to.equal(true);
    });

    it(`always shows a tooltip that is not a name`, () => {
      expect(onShowFor(`<button id="n" data-tippy-content="Next match (N)">next</button>`)(fits)).to.equal(true);
    });
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
