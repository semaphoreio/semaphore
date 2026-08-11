import { expect } from "chai"
import { byteLength } from "./limits"

describe("byteLength", () => {
  it("returns 0 for non-strings", () => {
    expect(byteLength(undefined)).to.equal(0)
    expect(byteLength(null)).to.equal(0)
    expect(byteLength(42)).to.equal(0)
  })

  it("matches char count for ASCII", () => {
    expect(byteLength("abc")).to.equal(3)
    expect(byteLength("a".repeat(100))).to.equal(100)
  })

  it("counts UTF-8 bytes for multi-byte characters", () => {
    expect(byteLength("ñ")).to.equal(2)
    expect(byteLength("✓")).to.equal(3)
    expect(byteLength("😀")).to.equal(4)
  })
})
