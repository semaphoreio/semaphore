import { v4 as uuidv4 } from 'uuid';
import { Utils } from "../utils";
import { LogLine } from "./log_line";

export class Command {
  constructor(options) {
    this.id = uuidv4();
    this.startingLineNumber = options.startingLineNumber
    this.directive = options.directive;
    this.startedAt = options.startedAt;
    this.finishedAt = options.finishedAt;
    this.logLines = new LogLines(options.startingLineNumber, this);
    this.renderingState = "waiting";
  }

  numberOfLines() {
    return this.logLines.size()
  }

  append(commandOutputEvent) {
    commandOutputEvent.forEachLine((line, isComplete) => {
      let timestamp = commandOutputEvent.timestamp
      this.logLines.addNewLogLineIfPreviousOneIsComplete(timestamp)

      this.logLines.last().append(line)
      this.logLines.last().timestamp = commandOutputEvent.timestamp
      this.logLines.last().isComplete = isComplete
      this.logLines.last().returnCarriage()
    })
  }

  isPassed() {
    return this.exitCode === 0;
  }

  isFailed() {
    return Utils.isNotBlank(this.exitCode) && !this.isPassed();
  }

  isFetching() {
    return !this.isFinished();
  }

  isFinished() {
    return Utils.isNotBlank(this.finishedAt);
  }

  hasEmptyOutput() {
    return this.logLines.empty()
  }

  finish(finishedAt, exitCode) {
    if(this.isFinished()) throw "Command is already finished";

    this.finishedAt = finishedAt;
    this.exitCode = exitCode;
  }
}

export class LogLines {
  constructor(startingLineNumber, command) {
    this.lines = []
    this.startingLineNumber = startingLineNumber
    this.command = command;
  }

  map(callback) {
    return this.lines.map((line) => {
      return callback(line);
    });
  }

  size() {
    return this.lines.length
  }

  at(index) {
    return this.lines[index]
  }

  empty() {
    return this.lines.length === 0
  }

  addNewEmpty(timestamp) {
    let number = this.startingLineNumber + this.lines.length

    let line = new LogLine({
      number: number,
      output: "",
      timestamp: timestamp,
      command: this.command,
      isComplete: false
    });

    this.lines.push(line)
  }

  addNewLogLineIfPreviousOneIsComplete(timestamp) {
    if(this.empty() || this.last().isComplete) {
      this.addNewEmpty(timestamp)
    }
  }

  last() {
    return this.lines[this.lines.length - 1];
  }
}

