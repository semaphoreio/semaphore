import {expect} from "chai"
import {projectUserRowMarkup} from "./user_row"

describe("projectUserRowMarkup", () => {
    afterEach(() => { document.body.innerHTML = "" })

    const user = (overrides) => Object.assign({
        id: "b2c3d4e5",
        name: "Ada Lovelace",
        github_login: "ada",
        has_avatar: true,
        avatar: "https://avatars.example.com/ada.png",
        subject_type: "user",
    }, overrides)

    // The markup is inserted with insertAdjacentHTML, so rendering it is the only way to
    // tell escaping from injection: a value that breaks out becomes a node.
    const render = (u, assetsPath = "/assets") => {
        const list = document.createElement("div")
        list.insertAdjacentHTML(`afterbegin`, projectUserRowMarkup(u, assetsPath))
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

    it("uses the avatar when the user has one", () => {
        const list = render(user())

        expect(list.querySelector("img").getAttribute("src"))
            .to.equal("https://avatars.example.com/ada.png")
    })

    it("falls back to the initial-based asset when the user has no avatar", () => {
        const list = render(user({has_avatar: false}))

        expect(list.querySelector("img").getAttribute("src"))
            .to.equal("/assets/images/org-a.svg")
    })

    it("renders an icon instead of an avatar for a service account", () => {
        const list = render(user({subject_type: "service_account"}))

        expect(list.querySelector("img")).to.equal(null)
        expect(list.textContent).to.contain("smart_toy")
    })

    it("omits the handle when the user has none", () => {
        const list = render(user({github_login: null}))

        expect(list.textContent).to.not.contain("@")
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

        it("escapes the assets path, which is read out of the page", () => {
            const list = render(user({has_avatar: false}), `x" onerror="alert(1)`)

            expect(list.querySelectorAll(INJECTED).length).to.equal(0)
            expect(list.querySelector("img").hasAttribute("onerror")).to.equal(false)
        })

        it("escapes the initial taken from the name", () => {
            const list = render(user({has_avatar: false, name: `"><img src=x onerror=alert(1)>`}))

            expect(list.querySelectorAll(INJECTED).length).to.equal(0)
        })

        it("escapes a name that carries markup", () => {
            const list = render(user({name: `<img src=x onerror=alert(1)>`}))

            expect(list.querySelectorAll(INJECTED).length).to.equal(0)
            expect(list.querySelector(".b").textContent).to.equal(`<img src=x onerror=alert(1)>`)
        })
    })
})
