import yaml from "js-yaml"

import { expect } from "chai"
import { Secrets } from "./secrets"
import { Workflow } from "./workflow"
import { Agent } from "./agent"

describe("Secrets", () => {

  Agent.setupTestAgentTypes();

  let dummyParent = {
    afterUpdate: () => {}
  }

  describe("#constructor", () => {
    it("creates secrets based on initial structure", () => {
      let pipeline1 = yaml.safeDump({
        "version": "1.0",
        "name": "A",
        "blocks": [
          {
            "name": "A",
            "task": {
              "secrets": [
                {"name": "a"},
                {"name": "b"}
              ]
            }
          }
        ]
      })

      let wf = new Workflow({yamls: [pipeline1]})
      let ppl = wf.pipelines[0]

      expect(ppl.blocks[0].secrets.toJson()).to.deep.equal([
        {name: "a"},
        {name: "b"}
      ])
    })
  })

  describe("#isEmpty", () => {
    it("returns true when the secrets are empty", () => {
      let secrets = new Secrets(dummyParent, [])

      expect(secrets.isEmpty()).to.equal(true)
    })

    it("returns false when the secrets are not empty", () => {
      let secrets = new Secrets(dummyParent, [{name: "abc"}])

      expect(secrets.isEmpty()).to.equal(false)
    })
  })

  describe("#include", () => {
    let secrets = new Secrets(dummyParent, [
      {name: "A"}
    ])

    it("returns false if secret is not found", () => {
      expect(secrets.includes("B")).to.equal(false)
    })

    it("returns true if secret is found", () => {
      expect(secrets.includes("A")).to.equal(true)
    })
  })

  describe("#add", () => {
    it("adds a secret to secrets", () => {
      let secrets = new Secrets(dummyParent, [])

      secrets.add("abc")

      expect(secrets.toJson()).to.deep.equal([{
        name: "abc"
      }])
    })

    it("keeps the secrets unique", () => {
      let secrets = new Secrets(dummyParent, [])

      secrets.add("abc")
      secrets.add("abc")
      secrets.add("abc")

      expect(secrets.toJson()).to.deep.equal([{
        name: "abc"
      }])
    })

    it("keeps the secrets sorted", () => {
      let secrets = new Secrets(dummyParent, [])

      secrets.add("b")
      secrets.add("a")
      secrets.add("c")

      expect(secrets.toJson()).to.deep.equal([
        {name: "a"},
        {name: "b"},
        {name: "c"},
      ])
    })
  })

  describe("#remove", () => {
    it("removes the secret by name", () => {
      let secrets = new Secrets(dummyParent, [
        {name: "a"},
        {name: "b"}
      ])

      secrets.remove("a")

      expect(secrets.toJson()).to.deep.equal([
        {name: "b"}
      ])
    })

    describe("removing all secrets", () => {
      it("leaves the collection empty", () => {
        let secrets = new Secrets(dummyParent, [
          {name: "a"},
          {name: "b"}
        ])

        secrets.remove("a")
        secrets.remove("b")

        expect(secrets.toJson()).to.deep.equal([])
      })
    })
  })

  describe("#validate", () => {
    describe("secret name is not available in the organization", () => {
      it("creates an error", () => {
        Secrets.setValidSecretNames(["a"])

        let secrets = new Secrets(dummyParent, [
          {name: "a"},
          {name: "b"}
        ])

        secrets.validate()

        let errors = secrets.map((s) => s.errors.list("name"))

        expect(errors[0]).to.deep.equal([])
        expect(errors[1]).to.deep.equal(["Secret is not available for this project or does not exist in the organization"])
      })
    })
  })

})
