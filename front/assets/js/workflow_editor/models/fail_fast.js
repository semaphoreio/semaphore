import _ from "lodash"

export class FailFast {
  constructor(parent, structure) {
    this.parent = parent
    this.structure = structure || {}

    this.stopStrategy = _.get(this.structure, ["stop", "when"], "")
    this.cancelStrategy = _.get(this.structure, ["cancel", "when"], "")
  }

  isDefined() {
    return this.stopStrategy !== "" || this.cancelStrategy !== ""
  }

  set(stop, cancel) {
    this.cancelStrategy = cancel
    this.stopStrategy = stop

    this.parent.afterUpdate()
  }

  setCancelStrategy(strategy) {
    this.set(this.stopStrategy, strategy)
  }

  setStopStrategy(strategy) {
    this.set(strategy, this.cancelStrategy)
  }

  getCancelStrategy() {
    return this.cancelStrategy
  }

  getStopStrategy() {
    return this.stopStrategy
  }

  toJson() {
    let res = {}

    if(this.stopStrategy !== "") {
      res["stop"] = {
        when: this.stopStrategy
      }
    }

    if(this.cancelStrategy !== "") {
      res["cancel"] = {
        when: this.cancelStrategy
      }
    }

    return res
  }
}
