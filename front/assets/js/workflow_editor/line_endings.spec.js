import { expect } from "chai"
import { LineEndings } from "./line_endings"

describe("LineEndings", () => {

  describe("#dominantLineEnding", () => {
    describe("when it has only CRLF", () => {
      it("returns CRLF", () => {
        let s = "version: v1.0\r\nname: P2\r\nblocks: []\r\n"

        expect(LineEndings.dominantLineEnding(s)).to.equal("\r\n")
      })
    })

    describe("when it has only LF", () => {
      it("returns LF", () => {
        let s = "version: v1.0\nname: P2\nblocks: []\n"

        expect(LineEndings.dominantLineEnding(s)).to.equal("\n")
      })
    })

    describe("more LF than CRLF", () => {
      it("returns LF", () => {
        let s = "version: v1.0\r\nname: P2\nblocks: []\n"

        expect(LineEndings.dominantLineEnding(s)).to.equal("\n")
      })
    })

    describe("more CRLF than LF", () => {
      it("returns CRLF", () => {
        let s = "version: v1.0\r\nname: P2\nblocks: []\r\n"

        expect(LineEndings.dominantLineEnding(s)).to.equal("\r\n")
      })
    })

    describe("equal LF and CRLF", () => {
      it("returns LF", () => {
        let s = "version: v1.0'\r\nname: P2\n\r\nblocks: []\n"

        expect(LineEndings.dominantLineEnding(s)).to.equal("\n")
      })
    })
  })

  describe("#enforceLineEnding", () => {
    it("can enforce CRLF", () => {
      let s = "version: v1.0\r\nname: P2\n\r\nblocks: []\n"

      expect(LineEndings.enforceLineEnding(s, "\r\n")).to.equal([
        "version: v1.0",
        "name: P2",
        "",
        "blocks: []",
        ""
      ].join("\r\n"))
    })

    it("can enforce LF", () => {
      let s = "version: v1.0\r\nname: P2\n\r\nblocks: []\n"

      expect(LineEndings.enforceLineEnding(s, "\n")).to.equal([
        "version: v1.0",
        "name: P2",
        "",
        "blocks: []",
        ""
      ].join("\n"))
    })
  })

})
