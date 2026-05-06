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
    // "ñ" = 2 bytes in UTF-8 (matches Elixir byte_size/1)
    expect(byteLength("ñ")).to.equal(2)
    // "✓" = 3 bytes
    expect(byteLength("✓")).to.equal(3)
    // emoji on supplementary plane = 4 bytes
    expect(byteLength("😀")).to.equal(4)
  })
})
