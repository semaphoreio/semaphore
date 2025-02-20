import { expect } from "chai"
import { Command } from "../command"
import { CommandTemplate } from "./command"

describe("CommandTemplate", () => {
  describe("render", () => {
    describe("when command has failed", () => {
      it("renders open command log", () => {
        let command = new Command({})
        let timestamp = 1345667;
        let exitCode = 2;
        command.finish(timestamp, exitCode);

        expect(CommandTemplate.render(command)).to.have.string("open");
      })
    })

    describe("when command has passed", () => {
      it("renders closed command log", () => {
        let command = new Command({})
        let timestamp = 1345667;
        let exitCode = 0;
        command.finish(timestamp, exitCode);

        expect(CommandTemplate.render(command)).not.to.have.string("open");
      })
    })

    describe("when the command is still running", () => {
      it("renders closed command log", () => {
        let command = new Command({})
        let isJobFinished = false;

        expect(CommandTemplate.render(command, isJobFinished)).to.have.string("open");
      })
    })

    describe("when command directive includes special characters", () => {
      it("escapes them", () => {
        let command = new Command({directive: "for i in {001..015}; do head -c 1M </dev/urandom >randfile$i; done"})
        expect(CommandTemplate.render(command)).to.have.string("for i in {001..015}; do head -c 1M &lt;/dev/urandom &gt;randfile$i; done");
      })
    })
  })

  describe("status", () => {
    describe("when command has passed", () => {
      it("returns 'Passed in'", () => {
        let command = new Command({})
        let timestamp = 1345667;
        let exitCode = 0;
        command.finish(timestamp, exitCode);

        expect(CommandTemplate.status(command)).to.eql("Passed in&nbsp;");
      })
    })

    describe("when command has failed", () => {
      it("returns 'Failed in'", () => {
        let command = new Command({})
        let timestamp = 1345667;
        let exitCode = 1;
        command.finish(timestamp, exitCode);

        expect(CommandTemplate.status(command)).to.eql("Failed in&nbsp;");
      })
    })

    describe("when command is incomplete and the job has finished", () => {
      it("returns 'Fetching'", () => {
        let command = new Command({})
        let isJobFinished = true;
        expect(CommandTemplate.status(command, isJobFinished)).to.eql("Fetching&nbsp;");
      })
    })

    describe("when command is incomplete and the job has finished", () => {
      it("returns 'Fetching'", () => {
        let command = new Command({})
        let isJobFinished = false;
        expect(CommandTemplate.status(command, isJobFinished)).to.eql("Running&nbsp;");
      })
    })
  })

  describe("duration", () => {
    describe("when command is finished", () => {
      it("returns total duration of command", () => {
        let startedAt = Date.now();
        let command = new Command({startedAt: startedAt});
        let finishedAt = startedAt + 40;
        let exitCode = 0;
        let isJobFinished = true;
        command.finish(finishedAt, exitCode);

        expect(CommandTemplate.duration(command, isJobFinished)).to.eql("<span seconds='40'>00:40</span>");
      })
    })

    describe("when command is still running", () => {
      it("returns running timer", () => {
        let startedAt = Date.now();
        let command = new Command({startedAt: startedAt});
        let exitCode = 0;
        let isJobFinished = false;

        expect(CommandTemplate.duration(command, isJobFinished)).to.include("timer run");
      })
    })

    describe("when job is finished but command isn't fully fetched", () => {
      it("returns blank duration", () => {
        let seconds = 3;
        let startedAt = Date.now() - (seconds * 1000);
        let command = new Command({startedAt: startedAt});
        let isJobFinished = true;

        expect(CommandTemplate.duration(command, isJobFinished)).to.eql("");
      })
    })
  })
})
