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
    describe("escapeCSSAttributeValue", () => {
        it("escapes single quotes", () => {
            const input = "Publish 'my-package' to Production";
            const escaped = Utils.escapeCSSAttributeValue(input);
            const expected = "Publish \\'my-package\\' to Production";
            expect(escaped).to.equal(expected);
        });

        it("escapes double quotes", () => {
            const input = 'Deploy "production" build';
            const escaped = Utils.escapeCSSAttributeValue(input);
            const expected = 'Deploy \\"production\\" build';
            expect(escaped).to.equal(expected);
        });

        it("escapes backslashes", () => {
            const input = "Path\\to\\file";
            const escaped = Utils.escapeCSSAttributeValue(input);
            const expected = "Path\\\\to\\\\file";
            expect(escaped).to.equal(expected);
        });

        it("escapes special characters", () => {
            const input = "test[data]:value.class#id";
            const escaped = Utils.escapeCSSAttributeValue(input);
            // When CSS.escape is available, it escapes brackets, colons, etc.
            // Fallback only escapes quotes and backslashes
            if (typeof CSS !== 'undefined' && CSS.escape) {
                expect(escaped).to.not.equal(input);
            } else {
                expect(escaped).to.equal(input);
            }
        });

        it("handles simple strings", () => {
            const input = "Simple-promotion_name123";
            const escaped = Utils.escapeCSSAttributeValue(input);
            // Simple alphanumeric strings with hyphens/underscores shouldn't need escaping
            expect(escaped).to.equal(input);
        });

        it("handles empty string", () => {
            expect(Utils.escapeCSSAttributeValue("")).to.equal("");
        });

        it("handles null/undefined", () => {
            expect(Utils.escapeCSSAttributeValue(null)).to.equal(null);
            expect(Utils.escapeCSSAttributeValue(undefined)).to.equal(undefined);
        });

        it("escapes complex strings with brackets and quotes", () => {
            const input = "test'][arbitrary-selector][data-x='some-value";
            const escaped = Utils.escapeCSSAttributeValue(input);
            const expected = "test\\'][arbitrary-selector][data-x=\\'some-value";
            expect(escaped).to.equal(expected);
        });

        it("can be used in DOM selectors", () => {
            const input = "Publish 'my-package' to Production";
            const escaped = Utils.escapeCSSAttributeValue(input);
            const expected = "Publish \\'my-package\\' to Production";
            expect(escaped).to.equal(expected);

            expect(() => {
                document.querySelector(`[data-promotion-target="${escaped}"]`);
            }).to.not.throw();
        });

        it("handles unicode characters (emoji)", () => {
            const input = "Deploy 🚀 to production";
            const escaped = Utils.escapeCSSAttributeValue(input);
            expect(escaped).to.equal(input);
        });

        it("handles unicode characters (accented letters)", () => {
            const input = "Déploiement en français";
            const escaped = Utils.escapeCSSAttributeValue(input);
            expect(escaped).to.equal(input);
        });

        it("handles unicode characters (Chinese)", () => {
            const input = "部署到生产环境";
            const escaped = Utils.escapeCSSAttributeValue(input);
            expect(escaped).to.equal(input);
        });

        it("handles mixed unicode and special characters", () => {
            const input = "Deploy 'app' 🚀 to Prod";
            const escaped = Utils.escapeCSSAttributeValue(input);
            const expected = "Deploy \\'app\\' 🚀 to Prod";
            expect(escaped).to.equal(expected);
        });
    });
})
