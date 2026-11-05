import { State } from "./state"
import { Events } from "./events"

// Thrown to unwind the fetch chain when the loop is stopped mid-flight.
class StoppedError extends Error {}

export var EventsFetcher = {
  init(options) {
    // Drop a loop left over from a previous job page before starting a new one.
    this.stop()

    this.stopped = false
    this.next = 0
    this.consecutiveErrorsCounter = 0
    this.maxConsecutiveErrors = options.maxConsecutiveErrors
    this.url = options.url
    this.token = options.token
    this.backOffInterval = options.backOffInterval
    this.regularInterval = options.regularInterval

    State.set("fetching", "in_progress")
  },

  //
  // Cancels the loop.
  //
  // The next tick is scheduled from inside the promise chain, so clearing the
  // pending timeout is not enough on its own - a fetch that is already in
  // flight would resolve afterwards and schedule another one. The flag makes
  // those continuations return instead.
  //
  stop() {
    this.stopped = true

    clearTimeout(this.timeout)
    this.timeout = null
  },

  scheduleTick(interval) {
    if (this.stopped) { return }

    this.timeout = setTimeout(this.tick.bind(this), interval)
  },

  tick() {
    if (this.stopped) { return }

    fetch(this.fetchUrl(), {credentials: 'same-origin', headers: this.fetchHeaders()})
    .then((response) => {
      if (this.stopped) { throw new StoppedError() }

      if (response.status == 200) {
        return response.json()
      }

      throw `Log request returned ${response.status}`
    })
    .then((data) => {
      this.resetConsecutiveErrorsCounter()

      Events.addItems(data.events)
      this.next = data.next

      if (this.hasNoMoreEventsToFetch()) {
        this.finish()
        this.afterFinish()
      } else if (data.events.length > 0) {
        this.scheduleTick(this.regularInterval)
      } else if (data.events.length == 0) {
        this.scheduleTick(this.backOffInterval)
      }
    })
    .catch((error) => {
      if (this.stopped || error instanceof StoppedError) { return }

      this.consecutiveErrorsCounter += 1

      if (this.consecutiveErrorsCounter < this.maxConsecutiveErrors) {
        this.scheduleTick(this.backOffInterval)
      } else {
        this.setFailureState()
        this.afterFinish()
      }
    })
  },

  setAfterFinish(callback) {
    this.afterFinishCallback = callback;
  },

  afterFinish() {
    if (this.afterFinishCallback) {
      this.afterFinishCallback()
    }
  },

  fetchUrl() {
    return this.url + "?token=" + this.next
  },

  fetchHeaders() {
    if (this.token) {
      return {
        "Authorization": `Bearer ${this.token}`
      };
    } else {
      return {};
    }
  },

  hasNoMoreEventsToFetch() {
    return this.next == null;
  },

  resetConsecutiveErrorsCounter() {
    this.consecutiveErrorsCounter = 0;
  },

  setFailureState() {
    State.set("fetching", "failure")
    State.set("failure_msg", "Something went wrong with fetching the log. Please contact Semaphore support.")
  },

  finish() {
    Events.stop()
    State.set("fetching", "finished")
  }
}
