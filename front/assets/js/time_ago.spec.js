import {expect} from "chai"
import {defineTimeAgoElement} from "./time_ago"

describe("time-ago", () => {
    beforeEach(() => {
        // Two things need undoing before the registry is usable here. jsdom-global
        // does not hoist customElements onto the global the way it does
        // document/window, and js/test_results/util/gzip.spec.ts swaps global.window
        // for a second jsdom without putting it back - so point both at the window
        // that actually owns `document`.
        globalThis.window = document.defaultView
        globalThis.customElements = document.defaultView.customElements

        defineTimeAgoElement()
    })

    afterEach(() => { document.body.innerHTML = "" })

    // The element reads `datetime` in its constructor, so it has to be present
    // before the element is upgraded - i.e. rendered as markup, like the server does.
    const render = (datetime) => {
        const attribute = datetime === undefined ? "" : ` datetime="${datetime}"`
        document.body.innerHTML = `<time-ago${attribute}></time-ago>`

        return document.body.firstElementChild
    }

    it("renders a relative time for something that just happened", () => {
        const el = render(new Date(Date.now() - 31 * 60 * 1000).toISOString())

        expect(el.textContent).to.equal("31 minutes ago")
    })

    it("exposes the exact timestamp as a tooltip so it never has to be worked out by hand", () => {
        const el = render(new Date(Date.now() - 31 * 60 * 1000).toISOString())

        expect(el.textContent).to.equal("31 minutes ago")
        expect(el.title).to.match(/\d{1,2}:\d{2}:\d{2}/)
        expect(el.title).to.contain(String(new Date().getFullYear()))
    })

    it("keeps the tooltip on entries old enough to render absolutely", () => {
        const el = render("2020-01-02T03:04:05+00:00")

        expect(el.textContent).to.not.contain("ago")
        expect(el.title).to.match(/\d{1,2}:\d{2}:\d{2}/)
        expect(el.title).to.contain("2020")
    })

    it("renders nothing without a datetime", () => {
        const el = render(undefined)

        expect(el.textContent).to.equal("")
    })

    it("reports an unparseable datetime rather than a bogus time", () => {
        const el = render("not-a-date")

        expect(el.textContent).to.equal("Invalid date")
    })
})
