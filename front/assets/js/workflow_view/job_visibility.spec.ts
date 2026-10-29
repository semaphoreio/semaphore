import { expect } from "chai";
import {
  filterReusedJobs,
  getJobVisibility,
  resetJobVisibility,
  setJobVisibility,
} from "./job_visibility";

describe(`Job visibility`, () => {
  afterEach(resetJobVisibility);

  const html = `<div class="block"><h4>Tests &amp; checks</h4>
    <a class="job-reused" href="/jobs/original">Reused success</a>
    <a href="/jobs/current">Current success</a>
    <a class="job-reused" href="/jobs/other">Another reused job</a>
    <div class="pending">Pending job</div></div>`;

  it(`defaults to all jobs and keeps pipeline selections independent`, () => {
    expect(getJobVisibility(`one`)).to.equal(`all`);
    setJobVisibility(`one`, `current`);
    expect(getJobVisibility(`one`)).to.equal(`current`);
    expect(getJobVisibility(`two`)).to.equal(`all`);
    resetJobVisibility();
    expect(getJobVisibility(`one`)).to.equal(`all`);
  });

  it(`preserves the original HTML in the all-jobs view`, () => {
    expect(filterReusedJobs(html, `all`)).to.equal(html);
  });

  it(`compacts reused rows without removing current successes or pending jobs`, () => {
    const filtered = document.createElement(`div`);
    filtered.innerHTML = filterReusedJobs(html, `current`);

    expect(filtered.querySelectorAll(`.job-reused`).length).to.equal(0);
    expect(filtered.querySelector(`h4`).textContent).to.equal(`Tests & checks`);
    expect(filtered.querySelector(`a`).getAttribute(`href`)).to.equal(`/jobs/current`);
    expect(filtered.querySelector(`.pending`).textContent).to.equal(`Pending job`);
    expect(filtered.textContent).to.contain(`2 reused jobs hidden`);
    expect(filterReusedJobs(html, `all`)).to.equal(html);
  });

  it(`keeps fully reused blocks as compact dependency context`, () => {
    const filtered = filterReusedJobs(
      `<div><h4>Build</h4><a class="job-reused" href="/jobs/build">Build</a></div>`,
      `current`,
    );
    expect(filtered).to.contain(`<h4>Build</h4>`);
    expect(filtered).to.contain(`1 reused job hidden`);
    expect(filtered).not.to.contain(`/jobs/build`);
  });

  it(`leaves blocks with no reused rows unchanged`, () => {
    const pending = `<div><h4>Pending</h4><div>Not started</div></div>`;
    expect(filterReusedJobs(pending, `current`)).to.equal(pending);
  });
});
