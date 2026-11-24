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

    // Both locale tests below compare against German output, so they say nothing on a
    // runtime without non-English ICU data. Assert that up front, so such a runtime
    // fails with the reason rather than with a confusing inequality.
    it("has the locale data the tooltip tests rely on", () => {
        const at = new Date("2026-09-09T10:01:30+00:00")

        expect(exact(at, "de"), "runtime is missing non-English ICU data").to.not.equal(exact(at, "en"))
    })

    it("formats the tooltip in the locale it is given", () => {
        const at = new Date("2026-09-09T10:01:30+00:00")

        expect(render(at.toISOString(), "de").title).to.equal(exact(at, "de"))
    })

    it("does not fall back to the relative text's English default for the tooltip", () => {
        const at = new Date("2026-09-09T10:01:30+00:00")
        const el = render(at.toISOString())

        // `locale` is what the visible relative text uses and it defaults to "en", so
        // comparing a no-attribute tooltip against the runtime default proves nothing
        // on an English runtime. Stand a different value in it instead: this fails if
        // formatExact ever reads it again, which is the English-only-tooltip bug.
        el.locale = "de"

        expect(el.formatExact(at)).to.equal(exact(at, undefined))
        expect(el.formatExact(at)).to.not.equal(exact(at, "de"))
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

    describe("always-relative", () => {
        const renderAlwaysRelative = (secondsAgo) => {
            const at = new Date(Date.now() - secondsAgo * 1000)
            document.body.innerHTML = `<time-ago always-relative datetime="${at.toISOString()}"></time-ago>`

            return document.body.firstElementChild
        }
        const day = 86400

        it("stays relative past the hour where the plain element switches to a date", () => {
            expect(renderAlwaysRelative(31 * 60).textContent).to.equal("31 minutes ago")
            expect(renderAlwaysRelative(3 * 3600 + 60).textContent).to.equal("3 hours ago")
            expect(renderAlwaysRelative(4 * day + 60).textContent).to.equal("4 days ago")
            expect(renderAlwaysRelative(1 * day + 60).textContent).to.equal("yesterday")
            expect(renderAlwaysRelative(65 * day).textContent).to.equal("2 months ago")
            expect(renderAlwaysRelative(800 * day).textContent).to.equal("2 years ago")
        })

        it("keeps the exact timestamp as a tooltip", () => {
            const el = renderAlwaysRelative(4 * day)

            expect(el.title).to.equal(exact(new Date(el.datetime), undefined))
        })

        it("is read when the element is attached, so it works when the attribute is set after creation", () => {
            const el = document.createElement("time-ago")
            el.datetime = new Date(Date.now() - 4 * day * 1000).toISOString()
            el.setAttribute("always-relative", "")
            document.body.appendChild(el)

            expect(el.textContent).to.equal("4 days ago")
        })

        it("leaves the plain element as it was", () => {
            document.body.innerHTML = `<time-ago datetime="${new Date(Date.now() - 4 * day * 1000).toISOString()}"></time-ago>`

            expect(document.body.firstElementChild.textContent).to.not.contain("ago")
        })
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
