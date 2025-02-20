import { expect } from "chai"
import { CommandFinishedEvent } from "./command_finished_event"

const event = {
  "event": "cmd_finished",
  "timestamp": 1607356861,
  "directive": "Connecting to cache",
  "exit_code": 0,
  "started_at": 1607356861,
  "finished_at": 1607356861
}

describe("CommandFinishedEvent", () => {
  it("has timestamp property", () => {
    expect(new CommandFinishedEvent(event)).to.have.property("timestamp");
  })

  it("has directive property", () => {
    expect(new CommandFinishedEvent(event)).to.have.property("directive");
  })

  it("has exitCode property", () => {
    expect(new CommandFinishedEvent(event)).to.have.property("exitCode");
  })

  it("has startedAt property", () => {
    expect(new CommandFinishedEvent(event)).to.have.property("startedAt");
  })

  it("has finishedAt property", () => {
    expect(new CommandFinishedEvent(event)).to.have.property("finishedAt");
  })

  describe("constructor", () => {
    it("throws an error when wrong arguments are provided", () => {
      expect(() => new CommandFinishedEvent()).to.throw();
    })
  })
})
