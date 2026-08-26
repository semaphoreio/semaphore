import { expect } from "chai"
import { h, render } from "preact"
import { useEffect } from "preact/hooks"
import { act } from "preact/test-utils"
import { islandRoot, unmountIslands, trackedIslandCount } from "./preact_islands"

describe("PreactIslands", () => {
  beforeEach(() => {
    unmountIslands()
    document.body.innerHTML = ""
  })

  const container = () => {
    const element = document.createElement("div")
    document.body.appendChild(element)
    return element
  }

  describe("islandRoot", () => {
    it("returns the element it was given", () => {
      const element = container()

      expect(islandRoot(element)).to.equal(element)
    })

    it("ignores a container that is not on the page", () => {
      expect(islandRoot(null)).to.equal(null)
      expect(trackedIslandCount()).to.equal(0)
    })

    it("tracks a container only once", () => {
      const element = container()

      islandRoot(element)
      islandRoot(element)

      expect(trackedIslandCount()).to.equal(1)
    })
  })

  describe("unmountIslands", () => {
    //
    // The behaviour the Turbo teardown depends on: the listeners these islands
    // register live on window, so only an unmount releases them.
    //
    it("runs the effect cleanups of a mounted island", () => {
      let released = false

      const Island = () => {
        useEffect(() => () => { released = true }, [])
        return null
      }

      // act() flushes the effect, which is what registers the cleanup. In a
      // browser it has run long before anyone navigates away.
      act(() => {
        render(h(Island, null), islandRoot(container()))
      })
      expect(released).to.equal(false)

      unmountIslands()

      expect(released).to.equal(true)
    })

    it("clears the island out of the container", () => {
      const element = islandRoot(container())
      render(h("p", null, "mounted"), element)
      expect(element.textContent).to.equal("mounted")

      unmountIslands()

      expect(element.textContent).to.equal("")
    })

    it("forgets the containers so a later page starts clean", () => {
      islandRoot(container())
      islandRoot(container())

      unmountIslands()

      expect(trackedIslandCount()).to.equal(0)
    })

    it("does nothing when no island was mounted", () => {
      expect(() => unmountIslands()).to.not.throw()
    })
  })
})
