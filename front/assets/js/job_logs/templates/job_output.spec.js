import { expect } from "chai";
import { Render } from "../render";
import { JobOutputTemplate } from "./job_output"
import { JobOutput } from "../job_output"

const { PerformanceObserver, performance } = require('perf_hooks');

describe("JobOutputTemplate", () => {
  describe("render", () => {
    it("renders 26_000 line output under 1s", () => {
      const events = require("../render.spec/40000_events.json").events;
      let jobOutput = new JobOutput();
      Render.buildJobOutput(jobOutput, events);

      let start = performance.now();
      JobOutputTemplate.render(jobOutput);
      let stop = performance.now();

      expect(jobOutput.numberOfLines).to.be.equal(26418);
      expect(stop - start).to.be.lessThan(1000);
    })
  })
})
