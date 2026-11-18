import {expect} from "chai"
import {groupUserRowMarkup} from "./user_row"

describe("groupUserRowMarkup", () => {
    afterEach(() => { document.body.innerHTML = "" })

    const user = (overrides) => Object.assign({
        id: "b2c3d4e5",
        name: "Ada Lovelace",
        github_login: "ada",
        avatar: "https://avatars.example.com/ada.png",
    }, overrides)

    // The markup is inserted with insertAdjacentHTML, so rendering it is the only way to
    // tell escaping from injection: a value that breaks out becomes a node.
    const render = (u) => {
        const list = document.createElement("div")
        list.insertAdjacentHTML(`afterbegin`, groupUserRowMarkup(u))
        document.body.appendChild(list)

        return list
    }

    const INJECTED = `img[src='x'],script,svg,iframe,[onerror],[onload],[onmouseover]`

    it("renders the user's name and handle", () => {
        const list = render(user())

        expect(list.querySelector(".b").textContent).to.equal("Ada Lovelace")
        expect(list.textContent).to.contain("@ada")
        expect(list.querySelector("div[id]").id).to.equal("b2c3d4e5")
    })

    it("keeps the remove button addressable by name", () => {
        const list = render(user())

        expect(list.querySelector(`[name="rmv_btn"]`)).to.not.equal(null)
    })

    it("renders a blank circle when the user has no avatar", () => {
        const list = render(user({avatar: null}))

        expect(list.querySelector("img")).to.equal(null)
    })

    describe("escaping", () => {
        it("escapes a handle that carries markup", () => {
            const list = render(user({github_login: `x<img src=x onerror=alert(1)>`}))

            expect(list.querySelectorAll(INJECTED).length).to.equal(0)
            expect(list.textContent).to.contain(`@x<img src=x onerror=alert(1)>`)
        })

        it("escapes an avatar url that breaks out of the src attribute", () => {
            const list = render(user({avatar: `x" onerror="alert(1)`}))

            expect(list.querySelectorAll(INJECTED).length).to.equal(0)
            expect(list.querySelector("img").hasAttribute("onerror")).to.equal(false)
            expect(list.querySelector("img").getAttribute("src")).to.equal(`x" onerror="alert(1)`)
        })

        it("escapes an id that breaks out of the id attribute", () => {
            const list = render(user({id: `x" onmouseover="alert(1)`}))

            expect(list.querySelectorAll(INJECTED).length).to.equal(0)
            expect(list.querySelector("div[id]").id).to.equal(`x" onmouseover="alert(1)`)
        })

        it("escapes a name that carries markup", () => {
            const list = render(user({name: `<img src=x onerror=alert(1)>`}))

            expect(list.querySelectorAll(INJECTED).length).to.equal(0)
            expect(list.querySelector(".b").textContent).to.equal(`<img src=x onerror=alert(1)>`)
        })
    })
})
