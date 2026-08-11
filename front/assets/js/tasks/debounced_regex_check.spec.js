import { expect } from "chai"
import sinon from "sinon"
import { DebouncedRegexCheck } from "./debounced_regex_check"

const versionParam = {
  validate_input_format: true,
  regex_pattern: "^[0-9]+\\.[0-9]+\\.[0-9]+$",
}

describe("DebouncedRegexCheck", () => {
  let clock

  beforeEach(() => { clock = sinon.useFakeTimers() })
  afterEach(() => { clock.restore() })

  it("reports no mismatch before the debounce delay elapses", () => {
    const checker = new DebouncedRegexCheck(versionParam, 300)
    checker.schedule("abc", () => {})
    expect(checker.mismatch("abc")).to.equal(false)
    clock.tick(299)
    expect(checker.mismatch("abc")).to.equal(false)
  })

  it("evaluates the regex once the debounce delay elapses", () => {
    const checker = new DebouncedRegexCheck(versionParam, 300)
    let notified = 0
    checker.schedule("abc", () => { notified += 1 })
    clock.tick(300)
    expect(notified).to.equal(1)
    expect(checker.mismatch("abc")).to.equal(true)
  })

  it("coalesces rapid schedule calls into a single evaluation of the last value", () => {
    const checker = new DebouncedRegexCheck(versionParam, 300)
    let notified = 0
    const onUpdate = () => { notified += 1 }

    checker.schedule("a", onUpdate)
    clock.tick(100)
    checker.schedule("ab", onUpdate)
    clock.tick(100)
    checker.schedule("1.2.3", onUpdate)
    clock.tick(300)

    expect(notified).to.equal(1)
    expect(checker.mismatch("1.2.3")).to.equal(false)
  })

  it("suppresses mismatch reporting while the cached value is stale", () => {
    const checker = new DebouncedRegexCheck(versionParam, 300)
    checker.schedule("abc", () => {})
    clock.tick(300)
    expect(checker.mismatch("abc")).to.equal(true)
    expect(checker.mismatch("abcd")).to.equal(false)
  })

  it("flush evaluates synchronously and cancels any pending timer", () => {
    const checker = new DebouncedRegexCheck(versionParam, 300)
    let notified = 0
    checker.schedule("abc", () => { notified += 1 })
    checker.flush("abc")

    expect(checker.mismatch("abc")).to.equal(true)
    expect(notified).to.equal(0)

    clock.tick(1000)
    expect(notified).to.equal(0)
  })

  it("flush reports no mismatch for a value that matches the pattern", () => {
    const checker = new DebouncedRegexCheck(versionParam, 300)
    checker.flush("1.2.3")
    expect(checker.mismatch("1.2.3")).to.equal(false)
  })
})
