import { expect } from "chai";
import { CommandStartedEvent } from "./command_started_event";

const event = {directive: "make test", timestamp: 1607430737}
const eventWithoutDirective = {timestamp: 1607430737}
const eventWithoutTimestamp = {directive: "make test"}

describe("CommandStartedEvent", () => {
  describe("constructor", () => {
    it("constructs object with directive property", () => {
      let object = new CommandStartedEvent(event)
      expect(object).to.have.property("directive");
    })

    it("constructs object with timestamp property", () => {
      let object = new CommandStartedEvent(event)
      expect(object).to.have.property("timestamp");
    })

    it("throws an error when directive is missing in params", () => {
      expect(() => new CommandStartedEvent(eventWithoutDirective)).to.throw();
    })

    it("throws an error when timestamp is missing in params", () => {
      expect(() => new CommandStartedEvent(eventWithoutTimestamp)).to.throw();
    })
  })
})
