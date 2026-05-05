import { expect } from "chai"
import {
  MAX_PARAM_VALUE_LENGTH,
  MAX_REGEX_PATTERN_LENGTH,
  regexMismatch,
  regexValidationMessage,
} from "./just_run_form"

describe("regexMismatch", () => {
  it("returns false when validate_input_format is disabled", async () => {
    let matcherCalled = false
    const param = { validate_input_format: false, regex_pattern: "^[0-9]+$" }
    expect(await regexMismatch(param, "abc", {
      matchFn: async () => {
        matcherCalled = true
        return { status: "mismatch" }
      }
    })).to.equal(false)
    expect(matcherCalled).to.equal(false)
  })

  it("returns false when regex_pattern is empty", async () => {
    const param = { validate_input_format: true, regex_pattern: "" }
    expect(await regexMismatch(param, "abc")).to.equal(false)
  })

  it("returns false for empty value (handled by required check)", async () => {
    const param = { validate_input_format: true, regex_pattern: "^[0-9]+$" }
    expect(await regexMismatch(param, "")).to.equal(false)
  })

  it("returns true when value does not match regex_pattern", async () => {
    const param = {
      validate_input_format: true,
      regex_pattern: "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    }
    expect(await regexMismatch(param, "not-a-version", {
      matchFn: async () => ({ status: "mismatch" })
    })).to.equal(true)
  })

  it("returns false when value matches regex_pattern", async () => {
    const param = {
      validate_input_format: true,
      regex_pattern: "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    }
    expect(await regexMismatch(param, "1.2.3", {
      matchFn: async () => ({ status: "match" })
    })).to.equal(false)
  })

  it("returns false when regex_pattern is invalid (defensive)", async () => {
    const param = { validate_input_format: true, regex_pattern: "[" }
    expect(await regexMismatch(param, "anything", {
      matchFn: async () => ({ status: "invalid" })
    })).to.equal(false)
  })

  it("does not flag mismatch when pattern is over the length cap (handled by dedicated rule)", async () => {
    const param = {
      validate_input_format: true,
      regex_pattern: "a".repeat(MAX_REGEX_PATTERN_LENGTH + 1)
    }
    expect(await regexMismatch(param, "anything")).to.equal(false)
  })

  it("does not flag mismatch when value is over the length cap (handled by dedicated rule)", async () => {
    const param = { validate_input_format: true, regex_pattern: "^a+$" }
    const value = "a".repeat(MAX_PARAM_VALUE_LENGTH + 1)
    expect(await regexMismatch(param, value)).to.equal(false)
  })
})

describe("regexValidationMessage", () => {
  it("returns a mismatch message when the timeboxed matcher reports mismatch", async () => {
    const param = { validate_input_format: true, regex_pattern: "^[0-9]+$" }
    const message = await regexValidationMessage(param, "abc", {
      matchFn: async () => ({ status: "mismatch" })
    })

    expect(message).to.equal("value does not match required format")
  })

  it("returns a timeout message when the timeboxed matcher times out", async () => {
    const param = { validate_input_format: true, regex_pattern: "^(a+)+$" }
    const message = await regexValidationMessage(param, "aaaaaaaaaaaaaaaa!", {
      matchFn: async () => ({ status: "timeout" })
    })

    expect(message).to.equal("value could not be validated quickly enough")
  })
})
