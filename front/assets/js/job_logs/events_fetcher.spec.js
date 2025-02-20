import { expect } from "chai";
import { EventsFetcher } from "./events_fetcher";
import { State } from "./state"
import { Events } from "./events"

global.fetch = require("node-fetch");

describe("EventsFetcher", () => {
  describe("tick", () => {
    it("sets failure after five consecutive fetch errors", (done) => {
      EventsFetcher.init({
        url: "localhost",
        maxConsecutiveErrors: 5,
        backOffInterval: 0,
        regularInterval: 0
      })

      EventsFetcher.setAfterFinish(() => {
        expect(EventsFetcher.consecutiveErrorsCounter).to.equal(5)
        expect(State.get("fetching")).to.equal("failure")
        expect(State.get("failure_msg")).to.equal("Something went wrong with fetching the log. Please contact Semaphore support.")
        done()
      })

      EventsFetcher.tick()
    })
  })

  describe("init", () => {
    it("sets fetching options", () => {
      EventsFetcher.init({
        url: "localhost",
        token: "jwtToken",
        maxConsecutiveErrors: 7,
        backOffInterval: 5000,
        regularInterval: 300
      })

      expect(EventsFetcher.url).to.equal("localhost")
      expect(EventsFetcher.token).to.equal("jwtToken")
      expect(EventsFetcher.next).to.equal(0)
      expect(EventsFetcher.maxConsecutiveErrors).to.equal(7)
      expect(EventsFetcher.backOffInterval).to.equal(5000)
      expect(EventsFetcher.regularInterval).to.equal(300)
      expect(State.get("fetching")).to.equal("in_progress")
    })
  })

  describe("fetchUrl", () => {
    it("returns fetch url", () => {
      EventsFetcher.init({url: "localhost"})
      expect(EventsFetcher.fetchUrl()).to.equal("localhost?token=0")
    })
  })

  describe("fetchHeaders", () => {
    it("returns no headers for no token", () => {
      EventsFetcher.init({url: "localhost"})
      expect(EventsFetcher.fetchHeaders()).to.eql({})
    })

    it("returns auth header when token is set", () => {
      EventsFetcher.init({url: "localhost", token: "jwtToken"})
      expect(EventsFetcher.fetchHeaders()).to.eql({"Authorization": "Bearer jwtToken"})
    })
  })

  describe("hasNoMoreEventsToFetch", () => {
    it("returns true if next token is null", () => {
      EventsFetcher.next = null;
      expect(EventsFetcher.hasNoMoreEventsToFetch()).to.be.true
    })

    it("returns false if next token isn't null", () => {
      EventsFetcher.next = 145;
      expect(EventsFetcher.hasNoMoreEventsToFetch()).to.be.false
    })
  })

  describe("resetConsecutiveErrorsCounter", () => {
    it("resets counter of consecutive fetch errors to zero", () => {
      EventsFetcher.consecutiveErrorsCounter = 5
      EventsFetcher.resetConsecutiveErrorsCounter()

      expect(EventsFetcher.consecutiveErrorsCounter).to.equal(0)
    })
  })

  describe("setFailureState", () => {
    it("sets failure state", () => {
      EventsFetcher.setFailureState()

      expect(State.get("fetching")).to.equal("failure")
      expect(State.get("failure_msg")).to.equal("Something went wrong with fetching the log. Please contact Semaphore support.")
    })
  })

  describe("finish", () => {
    it("stops fetching events", () => {
      EventsFetcher.finish()

      expect(Events.isRunning()).to.be.false
      expect(State.get("fetching")).to.equal("finished")
    })
  })
})
