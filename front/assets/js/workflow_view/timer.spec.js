import {expect} from "chai"
import {Timer} from "./timer"

describe("Timer", () => {
    afterEach(() => {
        Timer.stop()
        document.body.innerHTML = ""
    })

    const render = (seconds, run) => {
        const el = document.createElement("span")
        el.setAttribute("timer", "")
        el.setAttribute("seconds", seconds)
        if (run) el.setAttribute("run", "")
        document.body.appendChild(el)

        return el
    }

    describe("renderTime", () => {
        it("formats the elapsed seconds", () => {
            const el = render("3661")

            Timer.renderTime(el)

            expect(el.textContent).to.equal("01:01:01")
        })

        it("keeps the minutes field on a short duration", () => {
            const el = render("5")

            Timer.renderTime(el)

            expect(el.textContent).to.equal("00:05")
        })

        // Number() means seconds can never carry markup, so this pins the sink: nothing
        // may write innerHTML.
        it("writes the duration through a text sink", () => {
            const el = render("3661")
            let writes = 0
            Object.defineProperty(el, "innerHTML", {
                configurable: true,
                get: () => "",
                set: () => { writes += 1 },
            })

            Timer.renderTime(el)

            expect(writes).to.equal(0)
            expect(el.textContent).to.equal("01:01:01")
        })
    })

    describe("increment", () => {
        it("advances a running timer by a second", () => {
            const el = render("41", true)

            Timer.increment(el)

            expect(el.getAttribute("seconds")).to.equal("42")
        })

        it("leaves a timer that is not running alone", () => {
            const el = render("41")

            Timer.increment(el)

            expect(el.getAttribute("seconds")).to.equal("41")
        })
    })

    describe("tick", () => {
        it("advances and renders every timer on the page", () => {
            const running = render("41", true)
            const stopped = render("41")

            Timer.tick()

            expect(running.textContent).to.equal("00:42")
            expect(stopped.textContent).to.equal("00:41")
        })
    })

    describe("init", () => {
        it("replaces a previous ticker instead of stacking a second one", () => {
            Timer.init()
            const first = Timer.ticker

            Timer.init()

            expect(Timer.ticker).to.not.equal(first)
        })

        it("clears the ticker on stop", () => {
            Timer.init()

            Timer.stop()

            expect(Timer.ticker).to.equal(null)
        })
    })
})
