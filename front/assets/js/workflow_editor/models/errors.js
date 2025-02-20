import _ from "lodash"

export class Errors {
  constructor() {
    this._errors = {}
    this._errorsOnNested = {}
  }

  exists() {
    return _.keys(this._errors).length > 0 || _.keys(this._errorsOnNested).length > 0
  }

  reset() {
    this._errors = {}
    this._errorsOnNested = {}
  }

  list(type) {
    if(type) {
      return this._errors[type] || []
    } else {
      let res = []

      Object.keys(this._errors).forEach(k => res = res.concat(this._errors[k]))

      return res
    }
  }

  add(type, message) {
    this._errors[type] = this._errors[type] || []
    this._errors[type].push(message)
  }

  addNested(name, errors) {
    this._errorsOnNested[name] = errors
  }
}
