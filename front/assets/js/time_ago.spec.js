import {expect} from "chai"
import {TimeAgo, defineTimeAgoElement} from "./time_ago"

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

    // The element reads its attributes in the constructor, so they have to be present
    // before it is upgraded - i.e. rendered as markup, like the server does.
    const render = (datetime, locale) => {
        const attributes = [
            datetime === undefined ? "" : ` datetime="${datetime}"`,
            locale === undefined ? "" : ` locale="${locale}"`,
        ].join("")
        document.body.innerHTML = `<time-ago${attributes}></time-ago>`

        return document.body.firstElementChild
    }

    // Independently built so the assertions pin the whole formatted value - locale,
    // instant and option set - rather than just something time-shaped.
    const exact = (date, locale) => new Intl.DateTimeFormat(locale, {
        weekday: "short",
        day: "numeric",
        month: "short",
        year: "numeric",
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
        hour12: false,
        timeZoneName: "short",
    }).format(date)

    it("renders a relative time for something that just happened", () => {
        const el = render(new Date(Date.now() - 31 * 60 * 1000).toISOString())

        expect(el.textContent).to.equal("31 minutes ago")
    })

    it("exposes the exact timestamp as a tooltip so it never has to be worked out by hand", () => {
        const at = new Date(Date.now() - 31 * 60 * 1000)
        const el = render(at.toISOString())

        expect(el.textContent).to.equal("31 minutes ago")
        expect(el.title).to.equal(exact(at, undefined))
    })

    it("keeps the tooltip on entries old enough to render absolutely", () => {
        const at = new Date("2020-01-02T03:04:05+00:00")
        const el = render(at.toISOString())

        expect(el.textContent).to.not.contain("ago")
        expect(el.title).to.equal(exact(at, undefined))
    })

    it("formats the tooltip in the viewer's own locale, not a hardcoded English", () => {
        const at = new Date("2026-09-09T10:01:30+00:00")

        expect(render(at.toISOString(), "de").title).to.equal(exact(at, "de"))
        expect(exact(at, "de")).to.not.equal(exact(at, "en"))
    })

    it("formats the tooltip once, not on every tick of the relative-time timer", () => {
        const original = TimeAgo.prototype.formatExact
        let calls = 0
        TimeAgo.prototype.formatExact = function (date) {
            calls += 1
            return original.call(this, date)
        }

        try {
            const el = render(new Date(Date.now() - 31 * 60 * 1000).toISOString())
            el.updateTime()
            el.updateTime()

            expect(calls).to.equal(1)
        } finally {
            TimeAgo.prototype.formatExact = original
        }
    })

    it("renders nothing without a datetime", () => {
        const el = render(undefined)

        expect(el.textContent).to.equal("")
        expect(el.title).to.equal("")
    })

    it("reports an unparseable datetime rather than a bogus time", () => {
        const el = render("not-a-date")

        expect(el.textContent).to.equal("Invalid date")
        expect(el.title).to.equal("")
    })
})
