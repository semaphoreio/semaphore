import { v4 as uuidv4 } from 'uuid';

export class LogLine {
  constructor(options) {
    this.number = options.number;
    this.output = options.output;
    this.timestamp = options.timestamp;
    this.command = options.command;
    this.isComplete = options.isComplete;
  }

  timestampRelativeToCommandStartedAt() {
    return this.timestamp - this.command.startedAt;
  }

  append(output) {
    this.output += output;
  }

  returnCarriage() {
    let lastCarriageReturn = this.output.lastIndexOf("\r");
    this.output = this.output.slice(lastCarriageReturn + 1)
  }
}
