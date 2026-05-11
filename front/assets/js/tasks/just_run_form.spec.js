import { expect } from "chai"
import {
  MAX_PARAM_VALUE_LENGTH,
  MAX_REGEX_PATTERN_LENGTH,
  patternTooLong,
  regexMismatch,
  valueTooLong,
} from "./just_run_form"

describe("valueTooLong", () => {
  it("returns false for non-string", () => {
    expect(valueTooLong(undefined)).to.equal(false)
    expect(valueTooLong(null)).to.equal(false)
    expect(valueTooLong(42)).to.equal(false)
  })

  it("returns false for value within the cap", () => {
    expect(valueTooLong("a".repeat(MAX_PARAM_VALUE_LENGTH))).to.equal(false)
  })

  it("returns true for value over the cap", () => {
    expect(valueTooLong("a".repeat(MAX_PARAM_VALUE_LENGTH + 1))).to.equal(true)
  })

  it("counts bytes, not chars, so multi-byte values cross the cap sooner", () => {
    const value = "ñ".repeat(MAX_PARAM_VALUE_LENGTH / 2 + 1)
    expect(value.length).to.be.below(MAX_PARAM_VALUE_LENGTH)
    expect(valueTooLong(value)).to.equal(true)
  })
})

describe("patternTooLong", () => {
  it("returns false when validate_input_format is disabled", () => {
    expect(patternTooLong({
      validate_input_format: false,
      regex_pattern: "a".repeat(MAX_REGEX_PATTERN_LENGTH + 1)
    })).to.equal(false)
  })

  it("returns false when regex_pattern is missing", () => {
    expect(patternTooLong({ validate_input_format: true })).to.equal(false)
  })

  it("returns false when regex_pattern is within the cap", () => {
    expect(patternTooLong({
      validate_input_format: true,
      regex_pattern: "a".repeat(MAX_REGEX_PATTERN_LENGTH)
    })).to.equal(false)
  })

  it("returns true when regex_pattern exceeds the cap", () => {
    expect(patternTooLong({
      validate_input_format: true,
      regex_pattern: "a".repeat(MAX_REGEX_PATTERN_LENGTH + 1)
    })).to.equal(true)
  })
})

describe("regexMismatch", () => {
  it("returns false when validate_input_format is disabled", () => {
    const param = { validate_input_format: false, regex_pattern: "^[0-9]+$" }
    expect(regexMismatch(param, "abc")).to.equal(false)
  })

  it("returns false when regex_pattern is empty", () => {
    const param = { validate_input_format: true, regex_pattern: "" }
    expect(regexMismatch(param, "abc")).to.equal(false)
  })

  it("returns false for empty value (handled by required check)", () => {
    const param = { validate_input_format: true, regex_pattern: "^[0-9]+$" }
    expect(regexMismatch(param, "")).to.equal(false)
  })

  it("returns true when value does not match regex_pattern", () => {
    const param = {
      validate_input_format: true,
      regex_pattern: "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    }
    expect(regexMismatch(param, "not-a-version")).to.equal(true)
  })

  it("returns false when value matches regex_pattern", () => {
    const param = {
      validate_input_format: true,
      regex_pattern: "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    }
    expect(regexMismatch(param, "1.2.3")).to.equal(false)
  })

  it("returns false when regex_pattern is invalid (defensive)", () => {
    const param = { validate_input_format: true, regex_pattern: "[" }
    expect(regexMismatch(param, "anything")).to.equal(false)
  })

  it("does not flag mismatch when pattern is over the length cap (handled by dedicated rule)", () => {
    const param = {
      validate_input_format: true,
      regex_pattern: "a".repeat(MAX_REGEX_PATTERN_LENGTH + 1)
    }
    expect(regexMismatch(param, "anything")).to.equal(false)
  })

  it("does not flag mismatch when value is over the length cap (handled by dedicated rule)", () => {
    const param = { validate_input_format: true, regex_pattern: "^a+$" }
    const value = "a".repeat(MAX_PARAM_VALUE_LENGTH + 1)
    expect(regexMismatch(param, value)).to.equal(false)
  })
})
