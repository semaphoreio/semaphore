import { Command } from "./command"
import { LogLine } from "./log_line"

export class JobOutput {
  constructor() {
    this.numberOfLines = 0;
    this.commands = [];
  }

  markAllCommandsAsRendered() {
    this.commands.forEach((command) => {
      if (command.isFinished()) {
        command.renderingState = "finished";
      } else {
        command.renderingState = "in progress";
      }
    })
  }

  commandsWaitingToBeRendered() {
    return this.commands.filter((command) => command.renderingState === "waiting")
  }

  commandWithRenderingInProgress() {
    return this.commands.find((command) => command.renderingState === "in progress")
  }

  append(commandOutputEvent) {
    this.lastCommand().append(commandOutputEvent);
    this.recalculateNumberOfLines();
  }

  recalculateNumberOfLines() {
    this.numberOfLines = 0

    this.commands.forEach((c) => this.numberOfLines += c.numberOfLines())
  }

  createCommand(commandStartedEvent) {
    let command = new Command({
      directive: commandStartedEvent.directive,
      startedAt: commandStartedEvent.timestamp,
      startingLineNumber: this.numberOfLines + 1
    })

    this.commands.push(command);
    this.incrementNumberOfLines();

    return command;
  }

  finishLastCommand(commandFinishedEvent) {
    this.lastCommand().finish(commandFinishedEvent.finishedAt, commandFinishedEvent.exitCode);
  }

  killLastCommand(jobFinishedEvent) {
    let exitCode = -1;
    this.lastCommand().finish(jobFinishedEvent.timestamp, exitCode)
  }

  incrementNumberOfLines() {
    this.numberOfLines += 1;
  }

  numberOfLines() {
    return this.numberOfLines;
  }

  isEmpty() {
    return this.commands.length === 0;
  }

  lastCommand() {
    return this.commands[this.commands.length - 1];
  }
}
