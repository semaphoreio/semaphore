import { expect } from "chai"
import { Events } from "./events"
import { EventsFetcher } from "./events_fetcher"
import { Render } from "./render"
import { SleepDetector } from "../sleep_detector"

global.fetch = require("node-fetch")

//
// Turbo keeps window and document alive across visits, so everything the job
// log page starts has to be stoppable. These cover the contract JobLogs.stop
// depends on, one module at a time.
//
describe("job log teardown", () => {
  describe("Events.reset", () => {
    it("clears items left over from the previous job", () => {
      Events.addItems([{ event: "one" }, { event: "two" }])

      Events.reset()

      expect(Events.size()).to.equal(0)
    })

    it("marks the stream running again after a finished job stopped it", () => {
      Events.stop()
      expect(Events.isRunning()).to.equal(false)

      Events.reset()

      expect(Events.isRunning()).to.equal(true)
    })
  })

  describe("EventsFetcher.stop", () => {
    it("stops the loop from scheduling another tick", () => {
      EventsFetcher.init({
        url: "localhost",
        maxConsecutiveErrors: 5,
        backOffInterval: 0,
        regularInterval: 0
      })

      EventsFetcher.stop()
      EventsFetcher.scheduleTick(0)

      expect(EventsFetcher.timeout).to.equal(null)
    })

    it("makes tick a no-op once stopped", () => {
      EventsFetcher.init({
        url: "localhost",
        maxConsecutiveErrors: 5,
        backOffInterval: 0,
        regularInterval: 0
      })
      EventsFetcher.stop()

      // Would otherwise start a fetch and reschedule itself.
      expect(() => EventsFetcher.tick()).to.not.throw()
      expect(EventsFetcher.timeout).to.equal(null)
    })

    it("clears the stopped flag when a new job page initialises", () => {
      EventsFetcher.stop()
      expect(EventsFetcher.stopped).to.equal(true)

      EventsFetcher.init({
        url: "localhost",
        maxConsecutiveErrors: 5,
        backOffInterval: 0,
        regularInterval: 0
      })

      expect(EventsFetcher.stopped).to.equal(false)
    })
  })

  describe("Render.stop", () => {
    it("stops the render loop rescheduling itself", () => {
      Render.init({ div: "#job-log", isJobFinished: true })
      Render.stop()

      Render.tick()

      expect(Render.timeout).to.equal(null)
    })
  })

  describe("SleepDetector.stop", () => {
    it("clears the interval", () => {
      SleepDetector.init(() => {})
      expect(SleepDetector.ticker).to.not.equal(null)

      SleepDetector.stop()

      expect(SleepDetector.ticker).to.equal(null)
    })

    it("does not stack an interval when a second page initialises", () => {
      SleepDetector.init(() => {})
      const first = SleepDetector.ticker

      SleepDetector.init(() => {})

      expect(SleepDetector.ticker).to.not.equal(first)
      SleepDetector.stop()
    })
  })
})
