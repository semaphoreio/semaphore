import { expect } from "chai"
import { FailFast } from "./fail_fast"

describe("Fail Fast", () => {

  let dummyParent = {
    afterUpdate: () => {}
  }

  describe("no fail fast configured", () => {
    let ff = new FailFast(dummyParent, {})

    it("is not defined", () => {
      expect(ff.isDefined()).to.eq(false)
    })

    it("is has an empty cancel strategy", () => {
      expect(ff.getCancelStrategy()).to.eq("")
    })

    it("is has an empty stop strategy", () => {
      expect(ff.getStopStrategy()).to.eq("")
    })

    it("renders an empty json", () => {
      expect(ff.toJson()).to.deep.eq({})
    })
  })

  describe("cancel strategy is set", () => {
    let ff = new FailFast(dummyParent, {cancel: { when: "branch != 'master'" }})

    it("is defined", () => {
      expect(ff.isDefined()).to.eq(true)
    })

    it("is has a non-empty cancel strategy", () => {
      expect(ff.getCancelStrategy()).to.eq("branch != 'master'")
    })

    it("is has an empty stop strategy", () => {
      expect(ff.getStopStrategy()).to.eq("")
    })

    it("renders the cancel strategy", () => {
      expect(ff.toJson()).to.deep.eq({cancel: { when: "branch != 'master'" }})
    })
  })

  describe("stop strategy is set", () => {
    let ff = new FailFast(dummyParent, {stop: { when: "branch != 'master'" }})

    it("is defined", () => {
      expect(ff.isDefined()).to.eq(true)
    })

    it("is has a non-empty stop strategy", () => {
      expect(ff.getStopStrategy()).to.eq("branch != 'master'")
    })

    it("is has an empty cancel strategy", () => {
      expect(ff.getCancelStrategy()).to.eq("")
    })

    it("renders the cancel strategy", () => {
      expect(ff.toJson()).to.deep.eq({stop: { when: "branch != 'master'" }})
    })
  })

  describe("#set", () => {
    describe("setting stop and cancel to empty values", () => {
      let ff = new FailFast(dummyParent, {stop: { when: "branch != 'master'" }})

      it("sets the strategy to not defined", () => {
        expect(ff.isDefined()).to.eq(true)

        ff.set("", "")

        expect(ff.isDefined()).to.eq(false)
      })
    })
  })

})
