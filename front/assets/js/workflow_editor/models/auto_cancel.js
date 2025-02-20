import _ from "lodash"

export class AutoCancel {
  constructor(parent, structure) {
    this.parent = parent
    this.structure = structure || {}

    this.runningStrategy = _.get(this.structure, ["running", "when"], "")
    this.queuedStrategy = _.get(this.structure, ["queued", "when"], "")
  }

  isDefined() {
    return this.runningStrategy !== "" || this.queuedStrategy !== ""
  }

  set(running, queued) {
    this.runningStrategy = running
    this.queuedStrategy = queued

    this.parent.afterUpdate()
  }

  setRunningStrategy(strategy) {
    this.set(strategy, this.queuedStrategy)
  }

  setQueuedStrategy(strategy) {
    this.set(this.runningStrategy, strategy)
  }

  getQueuedStrategy() {
    return this.queuedStrategy
  }

  getRunningStrategy() {
    return this.runningStrategy
  }

  toJson() {
    let res = {}

    if(this.runningStrategy !== "") {
      res["running"] = {
        when: this.runningStrategy
      }
    }

    if(this.queuedStrategy !== "") {
      res["queued"] = {
        when: this.queuedStrategy
      }
    }

    return res
  }
}
