import { expect } from "chai"
import { Command } from "./command"
import { CommandOutputEvent } from "./events/command_output_event"
import { LogLines } from "./command"

describe("Command", () => {
  describe("constructor", () => {
    it("constructs command with ID", () => {
      expect(new Command({})).to.have.property("id");
    })

    it("constructs command with startingLineNumber", () => {
      expect(new Command({})).to.have.property("startingLineNumber");
    })

    it("constructs command with directive", () => {
      expect(new Command({})).to.have.property("directive");
    })

    it("constructs command with empty logLines", () => {
      let command = new Command({});

      expect(command).to.have.property("logLines");
      expect(command.logLines.empty()).to.equal(true)
    })

    it("constructs command with startedAt", () => {
      expect(new Command({})).to.have.property("startedAt");
    })

    it("constructs command with finishedAt", () => {
      expect(new Command({})).to.have.property("finishedAt");
    })
  })

  describe("isFinished", () => {
    it("returns true when finishedAt isn't null", () => {
      let command = new Command({finishedAt: Date.now()});
      expect(command.isFinished()).to.be.true;
    })

    it("returns false when finishedAt is null", () => {
      let command = new Command({});
      expect(command.isFinished()).to.be.false;
    })
  })

  describe("append", () => {
    describe("when event output has one line", () => {
      it("appends new lines to the command", () => {
        let command = new Command({});

        expect(command.logLines.size()).to.equal(0)
        command.append(new CommandOutputEvent({output: "Exporting env var", timestamp: 123456}));

        expect(command.logLines.size()).to.equal(1)
        expect(command.logLines.at(0).output).to.equal("Exporting env var");
      })
    })

    describe("when event output has multiple lines", () => {
      it("appends new lines to the command", () => {
        let command = new Command({});

        expect(command.logLines.size()).to.equal(0)
        command.append(new CommandOutputEvent({output: "Exporting env var\n$SEMAPHORE_PIPELINE", timestamp: 123456}));

        expect(command.logLines.size()).to.equal(2)
        expect(command.logLines.at(0).output).to.equal("Exporting env var");
        expect(command.logLines.at(1).output).to.equal("$SEMAPHORE_PIPELINE");
      })
    })

    describe("when command has incomplete last line", () => {
      it("appends the event output to the last line of command", () => {
        let command = new Command({});

        command.append(new CommandOutputEvent({output: "Exporting env var\n$SEMAPHORE_PIP", timestamp: 123456}));
        command.append(new CommandOutputEvent({output: "ELINE", timestamp: 123456}));

        expect(command.logLines.size()).to.equal(2)
        expect(command.logLines.at(0).output).to.equal("Exporting env var");
        expect(command.logLines.at(1).output).to.equal("$SEMAPHORE_PIPELINE");
      })
    })
  })

  describe("LogLines", () => {
    describe("map", () => {
      it("maps each line in collection to the callback result", () => {
        let logLines = new LogLines();

        logLines.addNewEmpty(123456);
        logLines.last().append("Exporting $SEMAPHORE_PIPELINE...")
        logLines.last().isComplete = true;

        logLines.addNewEmpty(123456);
        logLines.last().append("Exporting $SEMAPHORE_WORKFLOW...")
        logLines.last().isComplete = true;

        logLines.addNewEmpty(123456);
        logLines.last().append("Exporting $SEMAPHORE_ARTIFACT...")
        logLines.last().isComplete = true;

        let result = logLines.map((line) => {
          return line.output.replace("...", "");
        })

        expect(result.join("")).to.equal([
          "Exporting $SEMAPHORE_PIPELINE",
          "Exporting $SEMAPHORE_WORKFLOW",
          "Exporting $SEMAPHORE_ARTIFACT"
        ].join(""))
      })
    })
  })
})
