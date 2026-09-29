import {expect} from "chai"
import {CronParser} from "./cron_parser"

describe("CronParser", () => {
    afterEach(() => { document.body.innerHTML = "" })

    const render = (marker, expression) => {
        const el = document.createElement("span")
        el.setAttribute(marker, "")
        el.setAttribute("expression", expression)
        document.body.appendChild(el)

        return el
    }

    // Neither library lets markup out today, so these pin the sink rather than a
    // payload: nothing may write innerHTML, whatever the libraries start returning.
    const PAYLOAD = "<img src=x onerror=alert(1)>"

    const trapInnerHTML = (el) => {
        let writes = 0
        Object.defineProperty(el, "innerHTML", {
            configurable: true,
            get: () => "",
            set: () => { writes += 1 },
        })

        return () => writes
    }

    describe("when", () => {
        it("describes the expression", () => {
            const el = render("cron-when", "* * * * *")

            CronParser.when(el)

            expect(el.textContent).to.equal("Every minute, every hour, every day")
        })

        it("reports an unparseable expression instead of throwing", () => {
            const el = render("cron-when", "* * * * nope")

            expect(() => CronParser.when(el)).to.not.throw()
            expect(el.textContent).to.contain("DOW part contains invalid values")
        })

        it("ignores an element that is not marked cron-when", () => {
            const el = render("cron-next", "* * * * *")

            CronParser.when(el)

            expect(el.textContent).to.equal("")
        })

        it("writes the description through a text sink", () => {
            const el = render("cron-when", "* * * * *")
            const writes = trapInnerHTML(el)

            CronParser.when(el)

            expect(writes()).to.equal(0)
            expect(el.textContent).to.equal("Every minute, every hour, every day")
        })

        it("writes the parse error through a text sink too", () => {
            const el = render("cron-when", `* * * * ${PAYLOAD}`)
            const writes = trapInnerHTML(el)

            CronParser.when(el)

            expect(writes()).to.equal(0)
            expect(el.textContent).to.contain("DOW part contains invalid values")
        })
    })

    describe("next", () => {
        it("renders the next occurrence as text", () => {
            const el = render("cron-next", "* * * * *")

            CronParser.next(el)

            expect(el.textContent).to.match(/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC$/)
        })

        it("writes the occurrence through a text sink", () => {
            const el = render("cron-next", "* * * * *")
            const writes = trapInnerHTML(el)

            CronParser.next(el)

            expect(writes()).to.equal(0)
            expect(el.textContent).to.match(/UTC$/)
        })

        it("ignores an element that is not marked cron-next", () => {
            const el = render("cron-when", "* * * * *")

            CronParser.next(el)

            expect(el.textContent).to.equal("")
        })

        // next() has no catch, so a hostile expression never reaches the element. Pinned
        // so that adding one later has to decide, deliberately, how the error is rendered.
        it("throws on an unparseable expression rather than rendering one", () => {
            const el = render("cron-next", PAYLOAD)

            expect(() => CronParser.next(el)).to.throw()
            expect(el.textContent).to.equal("")
        })
    })

    describe("init", () => {
        it("fills every marked element on the page", () => {
            render("cron-when", "* * * * *")
            render("cron-next", "* * * * *")

            CronParser.init()

            const [when, next] = Array.from(document.body.children)
            expect(when.textContent).to.equal("Every minute, every hour, every day")
            expect(next.textContent).to.match(/UTC$/)
        })
    })
})
