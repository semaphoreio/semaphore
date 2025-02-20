import {expect} from "chai"
import {Utils} from "./utils"

describe("Utils", () => {
    describe("toHHMMSS", () => {
        it("returns duration in HH:MM:SS format when it is longer 59 minutes", () => {
            expect(Utils.toHHMMSS(3600)).to.equal("01:00:00")
        })

        it("returns duration in MM:SS format when it is less than an hour", () => {
            expect(Utils.toHHMMSS(119)).to.equal("01:59")
        })
    });
    describe("toHHMMSStruncated", () => {
        it("should return duration in HH:MM:SS format when it is longer than 59 minutes without milisecond", () => {
            expect(Utils.toHHMMSSTruncated(3600.5)).to.equal("01:00:00")
        })
    });
    describe("toSecond", () => {
        it('should return correct seconds from nanosecond',  () => {
            expect(Utils.toSeconds(36000000000)).to.equal(36)
        });
    });
})
