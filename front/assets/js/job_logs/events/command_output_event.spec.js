import { expect } from "chai";
import { CommandOutputEvent } from "./command_output_event";

const event = {timestamp: 1607430737, output: "Unpacking liblwp-mediatypes-perl (6.02-1) ..."}
const eventWithoutTimestamp = {output: "Unpacking liblwp-mediatypes-perl (6.02-1) ..."}
const eventWithoutOutput = {timestamp: 1607430737}

describe("CommandStartedEvent", () => {
  describe("constructor", () => {
    it("constructs object with output property", () => {
      let object = new CommandOutputEvent(event)
      expect(object).to.have.property("output");
    })

    it("constructs object with timestamp property", () => {
      let object = new CommandOutputEvent(event)
      expect(object).to.have.property("timestamp");
    })

    it("throws an error when output is missing in params", () => {
      expect(() => new CommandOutputEvent(eventWithoutOutput)).to.throw();
    })

    it("throws an error when timestamp is missing in params", () => {
      expect(() => new CommandOutputEvent(eventWithoutTimestamp)).to.throw();
    })
  })

  describe("forEachLine", () => {
    it("breaks up output into lines", () => {
      let event = new CommandOutputEvent({
        output: "Hello\nThere\nIncom",
        timestamp: 1
      })

      let result = []

      event.forEachLine((line, isComplete) => {
        result.push({line: line, isComplete: isComplete})
      })

      expect(result.length).to.equal(3)

      expect(result[0].line).to.equal("Hello")
      expect(result[0].isComplete).to.equal(true)

      expect(result[1].line).to.equal("There")
      expect(result[1].isComplete).to.equal(true)

      expect(result[2].line).to.equal("Incom")
      expect(result[2].isComplete).to.equal(false)
    })
  })

  describe("usePosixStyleNewLine", () => {
    it("replaces all occurrences of \r\n with \n", () => {
      let event = new CommandOutputEvent({
        output: "Hello\r\r\n\nThere\r\nIncom",
        timestamp: 1
      })

      event.usePosixStyleNewLine();
      expect(event.output).to.eql("Hello\nThere\nIncom")
    })
  })
})
