import { expect } from "chai"
import { TurboNavigation } from "./turbo_navigation"

describe("TurboNavigation", () => {
  beforeEach(() => {
    window.InjectedDataByBackend = { Watchman: {} }
    document.head.innerHTML = ""
  })

  describe("isEnabled", () => {
    it("is disabled when the backend did not set the flag", () => {
      expect(TurboNavigation.isEnabled()).to.equal(false)
    })

    it("is enabled only for a literal true", () => {
      window.InjectedDataByBackend.TurboNavigation = "true"
      expect(TurboNavigation.isEnabled()).to.equal(false)

      window.InjectedDataByBackend.TurboNavigation = true
      expect(TurboNavigation.isEnabled()).to.equal(true)
    })
  })

  describe("resetInjectedData", () => {
    it("drops keys belonging to the page being navigated away from", () => {
      window.InjectedDataByBackend.pipelineStatusUrl = "/workflows/1/status"
      window.InjectedDataByBackend.FilterOptions = ["master"]

      TurboNavigation.resetInjectedData()

      expect(window.InjectedDataByBackend.pipelineStatusUrl).to.equal(undefined)
      expect(window.InjectedDataByBackend.FilterOptions).to.equal(undefined)
    })

    it("keeps the document wide configuration", () => {
      window.InjectedDataByBackend.Environment = { Env: "prod" }
      window.InjectedDataByBackend.Posthog = { apiKey: "key" }
      window.InjectedDataByBackend.TurboNavigation = true

      TurboNavigation.resetInjectedData()

      expect(window.InjectedDataByBackend.Environment).to.deep.equal({ Env: "prod" })
      expect(window.InjectedDataByBackend.Posthog).to.deep.equal({ apiKey: "key" })
      expect(window.InjectedDataByBackend.TurboNavigation).to.equal(true)
    })

    it("restores the empty Watchman namespace set up in the head", () => {
      window.InjectedDataByBackend.Watchman = { metric: 1 }

      TurboNavigation.resetInjectedData()

      expect(window.InjectedDataByBackend.Watchman).to.deep.equal({})
    })
  })

  describe("pruneDuplicateNonceTags", () => {
    const nonceTags = () =>
      Array.from(document.querySelectorAll('meta[name="csp-nonce"]')).map((tag) => tag.content)

    it("keeps the nonce from the originally loaded page", () => {
      document.head.innerHTML = `
        <meta name="csp-nonce" content="original">
        <meta name="csp-nonce" content="second-visit">
        <meta name="csp-nonce" content="third-visit">
      `

      TurboNavigation.pruneDuplicateNonceTags()

      expect(nonceTags()).to.deep.equal(["original"])
    })

    it("leaves a single tag alone", () => {
      document.head.innerHTML = `<meta name="csp-nonce" content="original">`

      TurboNavigation.pruneDuplicateNonceTags()

      expect(nonceTags()).to.deep.equal(["original"])
    })

    it("does nothing when there is no nonce tag", () => {
      TurboNavigation.pruneDuplicateNonceTags()

      expect(nonceTags()).to.deep.equal([])
    })
  })
})
