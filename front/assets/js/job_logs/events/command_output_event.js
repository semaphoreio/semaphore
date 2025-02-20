import { Utils } from "../../utils"

export class CommandOutputEvent {
  constructor(options) {
    this.timestamp = options.timestamp;
    this.output = options.output;

    if(Utils.isBlank(this.timestamp)) throw("CommandOutputEvent can't have blank timestamp");
    if(Utils.isBlank(this.output)) throw("CommandOutputEvent can't have blank output");
  }

  usePosixStyleNewLine() {
    let output = this.output;

    while (output.includes("\r\n")) {
      output = output.replace("\r\n", "\n")
    }

    while(output.includes("\n\n")) {
      output = output.replace("\n\n", "\n")
    }

    this.output = output;
  }

  forEachLine(cb) {
    this.usePosixStyleNewLine();

    let start = 0;
    while(true) {
      let end = this.output.indexOf("\n", start)

      if(end === -1) {
        let line = this.output.substr(start)

        cb(line, false)

        break;
      } else {
        let line = this.output.substr(start, end - start)

        cb(line, true)
      }
      start = end + 1;
    }
  }
}
