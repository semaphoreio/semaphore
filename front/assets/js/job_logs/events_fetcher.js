import { State } from "./state"
import { Events } from "./events"

export var EventsFetcher = {
  init(options) {
    this.next = 0
    this.consecutiveErrorsCounter = 0
    this.maxConsecutiveErrors = options.maxConsecutiveErrors
    this.url = options.url
    this.token = options.token
    this.backOffInterval = options.backOffInterval
    this.regularInterval = options.regularInterval

    State.set("fetching", "in_progress")
  },

  tick() {
    fetch(this.fetchUrl(), {credentials: 'same-origin', headers: this.fetchHeaders()})
    .then((response) => {
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
        setTimeout(this.tick.bind(this), this.regularInterval)
      } else if (data.events.length == 0) {
        setTimeout(this.tick.bind(this), this.backOffInterval)
      }
    })
    .catch(() => {
      this.consecutiveErrorsCounter += 1

      if (this.consecutiveErrorsCounter < this.maxConsecutiveErrors) {
        setTimeout(this.tick.bind(this), this.backOffInterval)
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
