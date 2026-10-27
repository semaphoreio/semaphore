import { expect } from "chai";
import { render } from "preact";
import { act } from "preact/test-utils";
import sinon from "sinon";
import { InteractivePipelineTree } from "./interactive_pipeline_tree";
import { JobFilter } from "./job_filter";
import { getJobVisibility, resetJobVisibility } from "./job_visibility";

describe(`JobFilter`, () => {
  let container: HTMLDivElement;

  beforeEach(() => {
    container = document.createElement(`div`);
    document.body.appendChild(container);
    sinon.stub(InteractivePipelineTree, `redrawDiagrams`);
    sinon.stub(InteractivePipelineTree, `adjustSuccessorsTopMargins`);
  });

  afterEach(async () => {
    await act(() => render(null, container));
    container.remove();
    resetJobVisibility();
    sinon.restore();
  });

  const draw = (currentRun = 2, reused = 98, skipped = 0) => act(() => {
    render(<JobFilter pipelineId="pipeline-1" counts={{ currentRun, reused, skipped }}/>, container);
  });

  it(`shows counts with native controls and an exposed selected state`, async () => {
    await draw();
    const buttons = container.querySelectorAll(`button`);
    expect(buttons.length).to.equal(2);
    expect(buttons[0].textContent).to.equal(`All jobs (100)`);
    expect(buttons[0].getAttribute(`aria-pressed`)).to.equal(`true`);
    expect(container.querySelector(`[role="group"]`).getAttribute(`data-visibility`)).to.equal(`all`);
    expect(buttons[1].textContent).to.equal(`This run (2)`);
    expect(buttons[1].getAttribute(`type`)).to.equal(`button`);
    expect(buttons[1].getAttribute(`aria-pressed`)).to.equal(`false`);
  });

  it(`redraws only its pipeline and retains focus when changing the view`, async () => {
    await draw();
    const current = container.querySelectorAll(`button`)[1];
    current.focus();
    await act(() => current.click());

    expect(current.getAttribute(`aria-pressed`)).to.equal(`true`);
    expect(container.querySelector(`[role="group"]`).getAttribute(`data-visibility`)).to.equal(`current`);
    expect(document.activeElement).to.equal(current);
    expect(getJobVisibility(`pipeline-1`)).to.equal(`current`);
    expect(getJobVisibility(`pipeline-2`)).to.equal(`all`);
    expect((InteractivePipelineTree.redrawDiagrams as sinon.SinonStub).calledOnceWithExactly(`pipeline-1`)).to.equal(true);
    expect((InteractivePipelineTree.adjustSuccessorsTopMargins as sinon.SinonStub).calledOnce).to.equal(true);
    expect(container.querySelector(`[role="status"]`).textContent).to.equal(`98 reused jobs hidden`);
  });

  it(`restores the choice after polling remounts and refreshes counts`, async () => {
    await draw();
    await act(() => container.querySelectorAll(`button`)[1].click());
    await act(() => render(null, container));
    await draw(3, 97);

    expect(container.querySelectorAll(`button`)[1].getAttribute(`aria-pressed`)).to.equal(`true`);
    expect(container.querySelectorAll(`button`)[1].textContent).to.equal(`This run (3)`);
    expect(container.querySelector(`[role="status"]`).textContent).to.equal(`97 reused jobs hidden`);

    await act(() => container.querySelectorAll(`button`)[0].click());
    expect(getJobVisibility(`pipeline-1`)).to.equal(`all`);
    expect(container.querySelector(`[role="status"]`).textContent).to.equal(`97 reused jobs shown`);
  });

  it(`omits controls when there is no reused work`, async () => {
    await draw(5, 0);
    expect(container.querySelector(`button`)).to.equal(null);
  });

  it(`includes skipped jobs in the total without calling them current-run work`, async () => {
    await draw(2, 98, 4);
    expect(container.querySelectorAll(`button`)[0].textContent).to.equal(`All jobs (104)`);
    expect(container.querySelectorAll(`button`)[1].textContent).to.equal(`This run (2)`);
  });

  it(`explains the zero-current-jobs case rather than leaving a blank view`, async () => {
    await draw(0, 1);
    await act(() => container.querySelectorAll(`button`)[1].click());
    expect(container.textContent).to.contain(`This run (0)`);
    expect(container.querySelector(`[role="status"]`).textContent).to.equal(`1 reused job hidden`);
  });
});
