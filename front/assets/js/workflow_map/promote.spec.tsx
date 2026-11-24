import { expect } from "chai";
import { afterEach, before, beforeEach, describe, test } from "mocha";
import { render } from "preact";
import { act } from "preact/test-utils";

import { defineTimeAgoElement } from "../time_ago";
import { ApiPromotionEvent, Pipeline, Promotion } from "./model";
import { PromoteButton, PromoteDialog, Promotions, promoting } from "./promote";
import { focus, popover } from "./store";

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

  test(`is a primary button that says how many promotions the pipeline defines, whether they ran or not, in its tooltip`, async () => {
    for (const [promotions, tip] of [
      [[promotion(`Staging`, 2), promotion(`Production`, 0), promotion(`Canary`, 0)], `Promote: 3 promotions`],
      [[promotion(`Staging`, 1), promotion(`Production`, 1)], `Promote: 2 promotions`],
      [[promotion(`Production`, 0)], `Promote: 1 promotion`],
    ] as const) {
      await act(() => render(<PromoteButton p={{ id: `ci`, name: `Build`, promotions } as unknown as Pipeline}/>, root));
      const button = root.querySelector<HTMLElement>(`.wf-map-promote`);
      expect(button.classList.contains(`btn-primary`)).to.equal(true);
      expect(button.textContent).to.equal(`Promote ▾`);
      expect(button.dataset.tippyContent).to.equal(tip);
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
  const promotion = (name: string) => ({ name, events: [], can_promote: true, parameters: [], pipelines: [] }) as unknown as Promotion;
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

describe(`promotions menu reasons`, () => {
  let root: HTMLElement;
  const promotion = (name: string, can_promote: boolean, deployment: Promotion[`deployment`] = null) => ({ name, events: [], can_promote, deployment, parameters: [], pipelines: [] }) as unknown as Promotion;
  const row = (name: string) => [...root.querySelectorAll(`.wf-map-promotion`)].find((r) => r.querySelector(`.wf-map-promotion-name`).textContent === name);
  const show = (...promotions: Promotion[]) => act(() => render(<Promotions p={{ id: `ci`, name: `Build`, promotions } as unknown as Pipeline}/>, root));

  beforeEach(() => {
    root = document.createElement(`div`);
    document.body.appendChild(root);
  });

  afterEach(() => {
    render(null, root);
    root.remove();
  });

  test(`shows the deployment target's message when it blocks the promotion`, async () => {
    await show(promotion(`Production`, false, { name: `prod`, allowed: false, message: `Deployments from branch "dev" to prod Deployment Target are forbidden` }));
    const note = row(`Production`).querySelector(`.wf-map-promotion-note`);
    expect(note.textContent).to.equal(`Deployments from branch "dev" to prod Deployment Target are forbidden`);
    expect(note.classList.contains(`blocked`)).to.equal(true);
    expect(row(`Production`).querySelector(`button`).disabled).to.equal(true);
    expect(row(`Production`).querySelector(`.wf-map-promotion-icon`).textContent).to.equal(`lock`);
  });

  test(`names the deployment target when it sends no message`, async () => {
    await show(promotion(`Production`, false, { name: `prod`, allowed: false, message: null }));
    expect(row(`Production`).querySelector(`.wf-map-promotion-note`).textContent).to.equal(`Blocked by the prod deployment target`);
  });

  test(`says when the user may not promote at all`, async () => {
    await show(promotion(`Staging`, false), promotion(`Production`, false, { name: `prod`, allowed: true, message: `You can deploy to prod Deployment Target` }));
    for (const name of [`Staging`, `Production`]) {
      expect(row(name).querySelector(`.wf-map-promotion-note`).textContent).to.equal(`You don't have permission to promote`);
      expect(row(name).querySelector(`button`).disabled).to.equal(true);
    }
  });

  test(`shows no note for a promotion that can run and never ran`, async () => {
    await show(promotion(`Staging`, true), promotion(`Production`, true, { name: `prod`, allowed: true, message: `You can deploy to prod Deployment Target` }));
    for (const name of [`Staging`, `Production`]) {
      expect(row(name).querySelector(`.wf-map-promotion-note`)).to.equal(null);
      expect(row(name).querySelector(`button`).disabled).to.equal(false);
    }
  });
});

describe(`promotions menu times`, () => {
  let root: HTMLElement;
  const event = (triggered_at: number, over: Partial<ApiPromotionEvent> = {}): ApiPromotionEvent => ({ pipeline_id: `p${triggered_at}`, processed: true, result: `PASSED`, auto: false, triggered_at, author: `Ana Kowalska`, ...over });
  const promotion = (events: ApiPromotionEvent[], over: Partial<Promotion> = {}) => ({ name: `Production`, events, can_promote: true, deployment: null, parameters: [], pipelines: [], starting: false, ...over }) as unknown as Promotion;
  const show = (...promotions: Promotion[]) => act(() => render(<Promotions p={{ id: `ci`, name: `Build`, promotions } as unknown as Pipeline}/>, root));
  const notes = () => [...root.querySelectorAll(`.wf-map-promotion-note`)].map((n) => n.textContent);
  const time = () => root.querySelector<HTMLElement & { datetime: string, }>(`.wf-map-promotion-note time-ago`);

  before(() => {
    globalThis.customElements = document.defaultView.customElements;
    defineTimeAgoElement();
  });

  beforeEach(() => {
    root = document.createElement(`div`);
    document.body.appendChild(root);
  });

  afterEach(() => {
    render(null, root);
    root.remove();
  });

  test(`shows who promoted last and how long ago, on one line, with the full name on hover`, async () => {
    await show(promotion([event(1700000000), event(1700003600, { author: `Bo Svensson` })]));
    expect(notes()).to.deep.equal([`Bo S. · ${time().textContent}`]);
    expect(time().textContent).to.match(/ago$/);
    expect(time().datetime).to.equal(`2023-11-14T23:13:20.000Z`);
    expect(root.querySelector(`.wf-map-promotion-note`).getAttribute(`title`)).to.equal(`Bo Svensson`);
  });

  test(`says auto-promoted for an automatic promotion`, async () => {
    await show(promotion([event(1700000000, { auto: true, author: null })]));
    expect(notes()).to.deep.equal([`Auto-promoted · ${time().textContent}`]);
  });

  test(`shows the time of a failed promotion too`, async () => {
    await show(promotion([event(1700000000, { result: `FAILED`, pipeline_id: null })]));
    expect(notes()).to.deep.equal([`Failed to promote · ${time().textContent}`]);
    expect(time().datetime).to.equal(`2023-11-14T22:13:20.000Z`);
  });

  test(`shows no time while a promotion is starting or before the first one`, async () => {
    await show(promotion([event(1700000000), event(1700003600, { processed: false, result: `` })], { starting: true }));
    expect(notes()).to.deep.equal([`Starting promotion…`]);
    await show(promotion([]));
    expect(notes()).to.deep.equal([]);
    expect(time()).to.equal(null);
  });

  test(`still shows the latest promotion to someone who may not promote, next to the reason`, async () => {
    await show(promotion([event(1700000000)], { can_promote: false }));
    expect(notes()).to.deep.equal([`Ana K. · ${time().textContent}`, `You don't have permission to promote`]);
    expect(time().datetime).to.equal(`2023-11-14T22:13:20.000Z`);
  });

  test(`moves to the new time when another promotion comes in`, async () => {
    await show(promotion([event(1700000000)]));
    const first = time();
    await show(promotion([event(1700000000), event(1700007200)]));
    expect(time()).to.not.equal(first);
    expect(time().datetime).to.equal(`2023-11-15T00:13:20.000Z`);
  });
});

describe(`promotions menu runs`, () => {
  let root: HTMLElement;
  const run = (id: string, name: string, createdAt: number, over: Partial<Pipeline> = {}) =>
    ({ id, name, createdAt, runningAt: createdAt, doneAt: createdAt + 90, status: `passed`, attempt: 1, parameters: [], ...over }) as Pipeline;
  const promotion = (name: string, pipelines: Pipeline[], declared: string[] = []) =>
    ({ name, events: pipelines.map((r) => ({ pipeline_id: r.id, processed: true, result: `PASSED`, auto: false, triggered_at: r.createdAt, author: `Ana Kowalska` })), can_promote: true, deployment: null, parameters: declared.map((d) => ({ name: d })), pipelines, starting: false }) as unknown as Promotion;
  const show = (...promotions: Promotion[]) => act(() => render(<Promotions p={{ id: `ci`, name: `Build`, promotions } as unknown as Pipeline}/>, root));
  const runs = () => [...root.querySelectorAll(`.wf-map-run`)].map((r) => [r.querySelector(`.wf-map-run-name`).textContent, r.querySelector(`.wf-map-run-params`) && [...r.querySelectorAll(`.wf-map-run-params span`)].map((v) => v.textContent)]);

  beforeEach(() => {
    root = document.createElement(`div`);
    document.body.appendChild(root);
    focus.value = null;
  });

  afterEach(() => {
    render(null, root);
    root.remove();
  });

  test(`lists every run under its promotion, newest first, with its parameters under the name`, async () => {
    await show(
      promotion(`05 - Delete image`, [
        run(`a`, `Delete image`, 1700000000, { parameters: [{ name: `IMAGE_DATE`, value: `2026-11-01` }] }),
        run(`b`, `Delete image`, 1700003600, { attempt: 2, parameters: [{ name: `IMAGE_DATE`, value: `2026-11-08` }] }),
      ]),
      promotion(`PHP Noble`, [run(`c`, `PHP 8.5.11`, 1700000000, { parameters: [{ name: `PHP_VERSION_noble`, value: `8.5.11` }] })])
    );
    expect(runs()).to.deep.equal([
      [`Delete image#2`, [`IMAGE_DATE=2026-11-08`]],
      [`Delete image`, [`IMAGE_DATE=2026-11-01`]],
      [`PHP 8.5.11`, [`PHP_VERSION_noble=8.5.11`]],
    ]);
    expect(root.querySelector(`.wf-map-promotion-note`)).to.equal(null);
  });

  test(`shows a run's parameters in the order the promotion declares them, without the empty ones`, async () => {
    const parameters = [{ name: `EXTRA`, value: `1` }, { name: `NOTE`, value: `` }, { name: `REGION`, value: `eu` }, { name: `IMAGE`, value: `web:1.2` }];
    await show(promotion(`Production`, [run(`a`, `Production`, 1700000000, { parameters })], [`IMAGE`, `NOTE`, `REGION`]));
    expect(runs()).to.deep.equal([[`Production`, [`IMAGE=web:1.2`, `REGION=eu`, `EXTRA=1`]]]);
  });

  test(`gives a run without parameters no second line`, async () => {
    await show(promotion(`Staging`, [run(`s1`, `Staging`, 1700000000), run(`s0`, `Staging`, 1600000000, { parameters: [{ name: `NOTE`, value: `` }] })], [`NOTE`]));
    expect(runs()).to.deep.equal([[`Staging`, null], [`Staging`, null]]);
  });

  test(`keeps the parameters inside the run's link`, async () => {
    await show(promotion(`Production`, [run(`a`, `Production`, 1700000000, { parameters: [{ name: `REGION`, value: `eu` }] })]));
    expect(root.querySelector(`a.wf-map-run[href="?pipeline_id=a"] .wf-map-run-params`).textContent).to.equal(`REGION=eu`);
  });

  test(`shows a run on the map and closes the menu when it is clicked`, async () => {
    popover.value = { kind: `promote`, id: `ci`, x: 0, y: 0 } as typeof popover.value;
    await show(promotion(`Staging`, [run(`s1`, `Staging`, 1700000000)]));
    const click = new MouseEvent(`click`, { bubbles: true, cancelable: true });
    await act(() => {
      root.querySelector(`.wf-map-run`).dispatchEvent(click);
    });
    expect(click.defaultPrevented).to.equal(true);
    expect(popover.value).to.equal(null);
    expect(focus.value).to.include({ kind: `pipeline`, id: `s1` });
  });

  test(`links every run to its pipeline on this workflow's page`, async () => {
    await show(promotion(`Staging`, [run(`s1`, `Staging`, 1700000000), run(`s2`, `Staging`, 1700003600, { attempt: 2 })]));
    expect([...root.querySelectorAll(`a.wf-map-run`)].map((a) => a.getAttribute(`href`))).to.deep.equal([`?pipeline_id=s2`, `?pipeline_id=s1`]);
  });

  for (const key of [`metaKey`, `ctrlKey`, `shiftKey`, `altKey`]) {
    test(`leaves a ${key} click on a run to the browser and keeps the menu open`, async () => {
      popover.value = { kind: `promote`, id: `ci`, x: 0, y: 0 } as typeof popover.value;
      await show(promotion(`Staging`, [run(`s1`, `Staging`, 1700000000)]));
      const click = new MouseEvent(`click`, { bubbles: true, cancelable: true, [key]: true });
      await act(() => {
        root.querySelector(`.wf-map-run`).dispatchEvent(click);
      });
      expect(click.defaultPrevented).to.equal(false);
      expect(popover.value).to.not.equal(null);
      expect(focus.value).to.equal(null);
    });
  }

  test(`finds a promotion by a parameter of one of its runs`, async () => {
    await show(
      promotion(`05 - Delete image`, [run(`a`, `Delete image`, 1700000000, { parameters: [{ name: `IMAGE_DATE`, value: `2026-11-01` }] })]),
      promotion(`Staging`, [])
    );
    const filter = root.querySelector<HTMLInputElement>(`.wf-map-promotion-filter`);
    await act(() => {
      filter.value = `11-01`;
      filter.dispatchEvent(new Event(`input`, { bubbles: true }));
    });
    expect([...root.querySelectorAll(`.wf-map-promotion-name`)].map((n) => n.textContent)).to.deep.equal([`05 - Delete image`]);
  });
});
