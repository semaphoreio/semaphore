import { expect } from "chai";
import { CommandStartedEvent } from "./events/command_started_event";
import { CommandFinishedEvent } from "./events/command_finished_event";
import { JobFinishedEvent } from "./events/job_finished_event";
import { JobOutput } from "./job_output";

const commandStartedEvent = new CommandStartedEvent({timestamp: 123456, directive: "make test"});
const commandFinishedEvent = new CommandFinishedEvent({
  timestamp: 123456,
  directive: "make test",
  exit_code: 0,
  started_at: "654321",
  finished_at: "383838"
});
const jobFinishedEvent = new JobFinishedEvent({
  timestamp: 123456,
  result: "passed"
})

describe("JobOutput", () => {
  describe("createCommand", () => {
    it("creates new command based on event", () => {
      let jobOutput = new JobOutput();

      jobOutput.createCommand(commandStartedEvent);
      expect(jobOutput.commands).to.have.lengthOf(1);
    })

    it("creates new command with renderingState set to 'waiting' by default", () => {
      let jobOutput = new JobOutput();

      jobOutput.createCommand(commandStartedEvent)
      expect(jobOutput.lastCommand().renderingState).to.eql("waiting")
    })
  })

  describe("finishLastCommand", () => {
    it("marks last created command as finished", () => {
      let jobOutput = new JobOutput();

      jobOutput.createCommand(commandStartedEvent);
      jobOutput.finishLastCommand(commandFinishedEvent);

      expect(jobOutput.lastCommand().isFinished()).to.equal(true);
      expect(jobOutput.lastCommand().exitCode).to.equal(commandFinishedEvent.exitCode);
    })
  })

  describe("killLastCommand", () => {
    it("finishes last command with exit code -1", () => {
      let jobOutput = new JobOutput();
      jobOutput.createCommand(commandStartedEvent);
      jobOutput.killLastCommand(jobFinishedEvent);

      expect(jobOutput.lastCommand().isFinished()).to.equal(true);
      expect(jobOutput.lastCommand().exitCode).to.equal(-1);
    })
  })

  describe("commandsWaitingToBeRendered", () => {
    it("returns commands with renderingState field set to 'waiting'", () => {
      let jobOutput = new JobOutput();

      let cmd1 = jobOutput.createCommand(commandStartedEvent)
      let cmd2 = jobOutput.createCommand(commandStartedEvent)
      let cmd3 = jobOutput.createCommand(commandStartedEvent)

      cmd1.renderingState = "waiting"
      cmd2.renderingState = "waiting"
      cmd3.renderingState = "in progress"

      expect(jobOutput.commandsWaitingToBeRendered()).to.eql([cmd1, cmd2])
    })
  })

  describe("commandWithRenderingInProgress", () => {
    it("returns the first command in array with renderingState field set to 'in progress'", () => {
      let jobOutput = new JobOutput();

      let cmd1 = jobOutput.createCommand(commandStartedEvent)
      let cmd2 = jobOutput.createCommand(commandStartedEvent)
      let cmd3 = jobOutput.createCommand(commandStartedEvent)

      cmd1.renderingState = "in progress"
      cmd2.renderingState = "in progress"

      expect(jobOutput.commandWithRenderingInProgress()).to.eql(cmd1)
    })
  })

  describe("markAllCommandsAsRendered", () => {
    it("sets renderingState to 'finished' for finished commands", () => {
      let jobOutput = new JobOutput();

      let cmd1 = jobOutput.createCommand(commandStartedEvent)
      jobOutput.finishLastCommand(commandFinishedEvent)
      let cmd2 = jobOutput.createCommand(commandStartedEvent)
      jobOutput.finishLastCommand(commandFinishedEvent)
      let cmd3 = jobOutput.createCommand(commandStartedEvent)
      jobOutput.finishLastCommand(commandFinishedEvent)

      jobOutput.markAllCommandsAsRendered()

      expect(cmd1.renderingState).to.eql("finished")
      expect(cmd2.renderingState).to.eql("finished")
      expect(cmd3.renderingState).to.eql("finished")
    })

    it("sets renderingState to 'in progress' for not yet finished commands", () => {
      let jobOutput = new JobOutput();

      let cmd1 = jobOutput.createCommand(commandStartedEvent)
      let cmd2 = jobOutput.createCommand(commandStartedEvent)
      let cmd3 = jobOutput.createCommand(commandStartedEvent)

      jobOutput.markAllCommandsAsRendered()

      expect(cmd1.renderingState).to.eql("in progress")
      expect(cmd2.renderingState).to.eql("in progress")
      expect(cmd3.renderingState).to.eql("in progress")
    })
  })
})
