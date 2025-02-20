import {expect} from "chai"
import {Features} from "./features"

describe("Features", () => {
  describe("when feature is not set", () => {
    it("returns false", () => {
      Features.clear()
      expect(Features.isEnabled("parameterizedPromotions")).to.equal(false)
    })
  })

  describe("when feature is set to false", () => {
    it("returns false", () => {
      Features.clear()
      Features.setFeature("parameterizedPromotions", false)

      expect(Features.isEnabled("parameterizedPromotions")).to.equal(false)
    })
  })

  describe("when feature is set to true", () => {
    it("returns true", () => {
      Features.clear()
      Features.setFeature("parameterizedPromotions", true)

      expect(Features.isEnabled("parameterizedPromotions")).to.equal(true)
    })
  });

  describe("when features are set with init", () => {
    it("returns proper values", () => {
      Features.clear()
      Features.init({parameterizedPromotions: true})

      expect(Features.isEnabled("parameterizedPromotions")).to.equal(true)
      expect(Features.isEnabled("deploymentTargets")).to.equal(false)
    })
  })
})