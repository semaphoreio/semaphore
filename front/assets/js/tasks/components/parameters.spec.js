import { expect } from "chai"
import {
  MAX_PARAM_VALUE_LENGTH,
  MAX_REGEX_PATTERN_LENGTH,
  Parameter,
} from "./parameters"

describe("Parameter", () => {
  describe("validate", () => {
    it("requires non-blank name", () => {
      const p = new Parameter({ name: "" })
      p.validate()
      expect(p.validations.find(v => v.field === "name")).to.exist
    })

    it("rejects lowercase name", () => {
      const p = new Parameter({ name: "lower_case" })
      p.validate()
      expect(p.validations.find(v => v.field === "name")).to.exist
    })

    it("accepts valid env-var name", () => {
      const p = new Parameter({ name: "PARAM_NAME" })
      p.validate()
      expect(p.validations).to.deep.equal([])
    })
  })

  describe("regexPatternValidationMsg", () => {
    it("returns nothing when validate_input_format is false", () => {
      const p = new Parameter({
        name: "PARAM",
        validate_input_format: false,
        regex_pattern: "["
      })
      expect(p.regexPatternValidationMsg()).to.be.undefined
    })

    it("requires regex_pattern when validate_input_format is true", () => {
      const p = new Parameter({
        name: "PARAM",
        validate_input_format: true,
        regex_pattern: ""
      })
      expect(p.regexPatternValidationMsg()).to.match(/can't be blank/)
    })

    it("rejects invalid regex pattern", () => {
      const p = new Parameter({
        name: "PARAM",
        validate_input_format: true,
        regex_pattern: "["
      })
      expect(p.regexPatternValidationMsg()).to.match(/Invalid regex pattern/)
    })

    it("accepts valid regex pattern", () => {
      const p = new Parameter({
        name: "PARAM",
        validate_input_format: true,
        regex_pattern: "^[0-9]+$"
      })
      expect(p.regexPatternValidationMsg()).to.be.undefined
    })

    it("rejects regex pattern over the length cap", () => {
      const p = new Parameter({
        name: "PARAM",
        validate_input_format: true,
        regex_pattern: "a".repeat(MAX_REGEX_PATTERN_LENGTH + 1)
      })
      expect(p.regexPatternValidationMsg()).to.match(/too long/)
    })
  })

  describe("defaultValueValidationMsg", () => {
    it("rejects default_value not matching regex_pattern", () => {
      const p = new Parameter({
        name: "PARAM",
        validate_input_format: true,
        regex_pattern: "^[0-9]+$",
        default_value: "abc"
      })
      expect(p.defaultValueValidationMsg()).to.match(/does not match/)
    })

    it("accepts default_value matching regex_pattern", () => {
      const p = new Parameter({
        name: "PARAM",
        validate_input_format: true,
        regex_pattern: "^[0-9]+$",
        default_value: "123"
      })
      expect(p.defaultValueValidationMsg()).to.be.undefined
    })

    it("ignores default_value when validate_input_format is false", () => {
      const p = new Parameter({
        name: "PARAM",
        validate_input_format: false,
        regex_pattern: "^[0-9]+$",
        default_value: "abc"
      })
      expect(p.defaultValueValidationMsg()).to.be.undefined
    })

    it("ignores empty default_value", () => {
      const p = new Parameter({
        name: "PARAM",
        validate_input_format: true,
        regex_pattern: "^[0-9]+$",
        default_value: ""
      })
      expect(p.defaultValueValidationMsg()).to.be.undefined
    })

    it("rejects default_value over the length cap", () => {
      const p = new Parameter({
        name: "PARAM",
        validate_input_format: true,
        regex_pattern: "^[a]+$",
        default_value: "a".repeat(MAX_PARAM_VALUE_LENGTH + 1)
      })
      expect(p.defaultValueValidationMsg()).to.match(/too long/)
    })
  })

  describe("isValid", () => {
    it("returns false when regex_pattern invalid", () => {
      const p = new Parameter({
        name: "PARAM",
        validate_input_format: true,
        regex_pattern: "["
      })
      expect(p.isValid()).to.equal(false)
    })

    it("returns true when all checks pass", () => {
      const p = new Parameter({
        name: "VERSION",
        validate_input_format: true,
        regex_pattern: "^[0-9]+\\.[0-9]+\\.[0-9]+$",
        default_value: "1.0.0"
      })
      expect(p.isValid()).to.equal(true)
    })
  })
})
