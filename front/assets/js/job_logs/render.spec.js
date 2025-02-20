import { expect } from "chai";
import { Render } from "./render";
import { JobOutput } from "./job_output";

const { PerformanceObserver, performance } = require('perf_hooks');

describe("Render", () => {
  const events = require("./render.spec/40000_events.json").events
  const eventsWithNoCommands = require("./render.spec/events_with_no_commands.json").events

  describe("buildJobOutput", () => {
    it("constructs job output with 40_000 events in less than 200ms", () => {
      let jobOutput = new JobOutput();

      let start = performance.now();
      Render.buildJobOutput(jobOutput, events);
      let stop = performance.now();

      expect(stop - start).to.be.lessThan(200);
      expect(jobOutput.numberOfLines).to.be.equal(26418);
    })

    it("constructs job output without any commands", () => {
      let jobOutput = new JobOutput();
      Render.buildJobOutput(jobOutput, eventsWithNoCommands);
      expect(jobOutput.numberOfLines).to.be.equal(0);
      expect(jobOutput.commands.length).to.be.equal(0);
    })
  })

  describe("render", () => {
    it("marks all commands in complete log as rendered", () => {
      let jobOutput = new JobOutput();
      Render.buildJobOutput(jobOutput, events);

      jobOutput.commands.forEach((command) => {
        expect(command.renderingState).to.eql("waiting")
      })

      Render.render(jobOutput, events);

      jobOutput.commands.forEach((command) => {
        expect(command.renderingState).to.eql("finished")
      })
    })
  })
})
