import _ from "lodash"

export class ExecutionTimeLimit {
  constructor(parent, structure) {
    this.parent = parent // can be block or pipeline
    this.structure = structure

    this._isDefined = (this.structure !== null && this.structure !== undefined)

    if(this._isDefined) {
      if(_.has(this.structure, ["hours"])) {
        this.unit = "hours"
        this.value = this.structure["hours"]
      } else if(_.has(this.structure, ["minutes"])) {
        this.unit = "minutes"
        this.value = this.structure["minutes"]
      } else {
        throw "Execution time limit has broken structure"
      }
    }
  }

  isDefined() {
    return this._isDefined
  }

  getUnit() {
    return this._isDefined ? this.unit : "hours"
  }

  getValue() {
    return this._isDefined ? this.value : 1
  }

  change(unit, value) {
    if(!_.isNumber(value)) {
      throw "Value must be a number"
    }

    if(unit !== "hours" && unit !== "minutes") {
      throw "Unit must be hours or minutes"
    }

    this._isDefined = true
    this.unit = unit
    this.value = value

    this.parent.afterUpdate()
  }

  toJson() {
    let res = {}
    res[this.unit] = this.value

    return res
  }
}
