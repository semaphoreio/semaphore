import { expect } from "chai"

import { Model } from "./model"

const project = (id, name) => ({ id: id, type: "project", name: name, path: `/projects/${name}` })
const dashboard = (id, name) => ({ id: id, type: "dashboard", name: name, path: `/dashboards/${name}` })

describe("JumpTo Model", () => {
  //
  // Mirrors the backend payload: starred items first, then the unstarred
  // projects and dashboards, each group already sorted alphabetically.
  //
  const build = (current) =>
    new Model(
      [project("backend-id", "Backend")],
      [project("frontend-id", "Frontend"), project("zebra-id", "Zebra")],
      [dashboard("dash-id", "My Dashboard")],
      current
    )

  describe("selectedIndex", () => {
    it("starts on the project of the current page", () => {
      expect(build({ id: "frontend-id", path: "/projects/Frontend" }).selectedIndex).to.equal(1)
    })

    it("finds the current project on a nested page", () => {
      const model = build({ id: "zebra-id", path: "/workflows/aa-bb-cc" })

      expect(model.selectedIndex).to.equal(2)
    })

    it("falls back to the path when there is no current project id", () => {
      const model = build({ id: null, path: "/dashboards/My Dashboard" })

      expect(model.selectedIndex).to.equal(3)
    })

    it("matches a path below the item path", () => {
      const model = build({ id: null, path: "/projects/Frontend/settings" })

      expect(model.selectedIndex).to.equal(1)
    })

    it("does not match a project whose path is a prefix of the current one", () => {
      const model = new Model([], [project("front-id", "front")], [], {
        id: null,
        path: "/projects/frontend"
      })

      expect(model.selectedIndex).to.equal(0)
    })

    it("selects the first item off a project page", () => {
      expect(build({ id: null, path: "/" }).selectedIndex).to.equal(0)
    })

    it("selects the first item when nothing is passed in", () => {
      expect(build(undefined).selectedIndex).to.equal(0)
    })
  })

  describe("changeFilter", () => {
    it("selects the first match while filtering", () => {
      const model = build({ id: "frontend-id", path: "/projects/Frontend" })

      model.changeFilter("z")

      expect(model.selectedIndex).to.equal(0)
      expect(model.results.map((r) => r.name)).to.deep.equal(["Zebra"])
    })

    it("returns to the current project when the filter is cleared", () => {
      const model = build({ id: "frontend-id", path: "/projects/Frontend" })

      model.changeFilter("z")
      model.changeFilter("")

      expect(model.selectedIndex).to.equal(1)
    })
  })

  describe("orderedResults", () => {
    it("groups starred, then projects, then dashboards", () => {
      const model = build({})

      expect(model.orderedResults().map((r) => r.name)).to.deep.equal([
        "Backend",
        "Frontend",
        "Zebra",
        "My Dashboard"
      ])
    })

    it("is a flat alphabetical list while filtering", () => {
      const model = build({})

      model.changeFilter("a")

      expect(model.orderedResults().map((r) => r.name)).to.deep.equal([
        "Backend",
        "My Dashboard",
        "Zebra"
      ])
    })
  })
})
