import { expect } from "chai"
import { Command } from "./command"
import { LogLine } from "./log_line"

describe("LogLine", () => {
  describe("timestampRelativeToCommandStartedAt", () => {
    it("returns number of seconds in HH:MM:SS format", () => {
      let command = new Command({startedAt: 100});
      let logLine = new LogLine({command: command, timestamp: 150});
      expect(logLine.timestampRelativeToCommandStartedAt()).to.equal(50);
    })
  })

  describe("returnCarriage", () => {
    it("clears everything until the last occurrence of \r", () => {
      let logLine = new LogLine({});
      logLine.output = "My name is...What?\rMy name is...Who?\rMy name is Chika-chika slim shady";
      logLine.returnCarriage();

      expect(logLine.output).to.eql("My name is Chika-chika slim shady");
    })
  })
})
