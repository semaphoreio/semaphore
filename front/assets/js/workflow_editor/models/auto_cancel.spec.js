import { expect } from "chai"
import { AutoCancel } from "./auto_cancel"

describe("Auto Cancel", () => {

  let dummyParent = {
    afterUpdate: () => {}
  }

  describe("no fail fast configured", () => {
    let ac = new AutoCancel(dummyParent, {})

    it("is not defined", () => {
      expect(ac.isDefined()).to.eq(false)
    })

    it("is has an empty running strategy", () => {
      expect(ac.getRunningStrategy()).to.eq("")
    })

    it("is has an empty queued strategy", () => {
      expect(ac.getQueuedStrategy()).to.eq("")
    })

    it("renders an empty json", () => {
      expect(ac.toJson()).to.deep.eq({})
    })
  })

  describe("queued strategy is set", () => {
    let ac = new AutoCancel(dummyParent, {queued: { when: "branch != 'master'" }})

    it("is defined", () => {
      expect(ac.isDefined()).to.eq(true)
    })

    it("is has a non-empty queued strategy", () => {
      expect(ac.getQueuedStrategy()).to.eq("branch != 'master'")
    })

    it("is has an empty running strategy", () => {
      expect(ac.getRunningStrategy()).to.eq("")
    })

    it("renders the queued strategy", () => {
      expect(ac.toJson()).to.deep.eq({queued: { when: "branch != 'master'" }})
    })
  })

  describe("running strategy is set", () => {
    let ac = new AutoCancel(dummyParent, {running: { when: "branch != 'master'" }})

    it("is defined", () => {
      expect(ac.isDefined()).to.eq(true)
    })

    it("is has a non-empty running strategy", () => {
      expect(ac.getRunningStrategy()).to.eq("branch != 'master'")
    })

    it("is has an empty queued strategy", () => {
      expect(ac.getQueuedStrategy()).to.eq("")
    })

    it("renders the running strategy", () => {
      expect(ac.toJson()).to.deep.eq({running: { when: "branch != 'master'" }})
    })
  })

  describe("#set", () => {
    describe("setting running and queued to empty values", () => {
      let ac = new AutoCancel(dummyParent, {running: { when: "branch != 'master'" }})

      it("sets the strategy to not defined", () => {
        expect(ac.isDefined()).to.eq(true)

        ac.set("", "")

        expect(ac.isDefined()).to.eq(false)
      })
    })
  })

})
