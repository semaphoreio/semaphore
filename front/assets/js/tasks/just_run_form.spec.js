import { expect } from "chai"
import { regexMismatch } from "./just_run_form"

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
})
