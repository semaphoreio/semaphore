import { regexMismatch } from "./limits"

export class DebouncedRegexCheck {
  constructor(parameter, delayMs = 300) {
    this.parameter = parameter
    this.delayMs = delayMs
    this.timer = null
    this.lastValue = null
    this.lastMismatch = false
    this.onUpdate = null
  }

  schedule(value, onUpdate) {
    this.onUpdate = onUpdate
    if (this.timer) { clearTimeout(this.timer) }
    this.timer = setTimeout(() => {
      this.timer = null
      this.evaluate(value)
      if (typeof this.onUpdate === "function") { this.onUpdate() }
    }, this.delayMs)
  }

  flush(value) {
    if (this.timer) { clearTimeout(this.timer) }
    this.timer = null
    this.evaluate(value)
  }

  mismatch(value) {
    if (value !== this.lastValue) { return false }
    return this.lastMismatch
  }

  evaluate(value) {
    this.lastValue = value
    this.lastMismatch = regexMismatch(this.parameter, value)
  }
}
