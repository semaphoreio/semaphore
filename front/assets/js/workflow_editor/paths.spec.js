import { expect } from "chai"
import { Paths } from "./paths"

describe("Paths", () => {

  describe("#relative", () => {
    describe("in the same directory", () => {
      it("returns file-name of 'to' without directory", () => {
        expect(Paths.relative(".semaphore/a.yml", ".semaphore/b.yml")).to.equal("b.yml")
      })
    })
  })

})
