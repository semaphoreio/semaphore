import yaml from "js-yaml"

import { expect } from "chai"
import { Workflow } from "./workflow"
import { Pipeline } from "./pipeline"
import { Agent } from "./agent"

describe("Pipeline", () => {

  Agent.setupTestAgentTypes();

  describe("#updateYaml", () => {
    describe("invalid YAML", () => {
      let wf = null
      let ppl = null
      let brokenYaml = `
version: 1.0
 containers:
   - name: "A"
      `

      beforeEach(() => {
        wf = new Workflow({yamls: [
          yaml.safeDump({
            "version": "1.0",
            "blocks": [{"name": "A"}]
          })
        ]})

        ppl = wf.pipelines[0]
      })

      it("sets the structure to {}", () => {
        expect(ppl.structure).to.not.deep.equal({})

        ppl.updateYaml(brokenYaml)

        expect(ppl.structure).to.deep.equal({})
      })

      it("has an invalid YAML", () => {
        expect(ppl.hasInvalidYaml()).to.equal(false)

        ppl.updateYaml(brokenYaml)

        expect(ppl.hasInvalidYaml()).to.equal(true)
      })

      it("sets yamlError", () => {
        expect(ppl.yamlError).to.equal(null)

        ppl.updateYaml(brokenYaml)

        expect(ppl.yamlError).to.an.instanceOf(yaml.YAMLException)
      })
    })
  })

  describe("validations", () => {
    describe("name", () => {
      it("validates that names are non-empty", () => {
        let wf = new Workflow({yamls: [
          yaml.safeDump({
            "version": "1.0",
            "blocks": [{"name": "A"}]
          })
        ]})

        let p = wf.pipelines[0]

        p.validate()

        expect(p.errors.list("name")).to.deep.equal([
          "Pipeline name can't be blank."
        ])

        p.changeName("A")
        p.validate()

        expect(p.errors.list("name")).to.deep.equal([])
      })
    })
  })

  describe("#toJson", () => {
    it("returns the pipeline as JSON", () => {
      let wf = new Workflow({yamls: [
        yaml.safeDump({
          "version": "1.0",
          "name": "A",
          "blocks": [{"name": "A"}]
        })
      ]})

      let p = wf.pipelines[0]

      expect(p.toJson()).to.deep.equal({
        "agent": {
          "machine": {
            "os_image": "ubuntu2004",
            "type": "e1-standard-2"
          }
        },
        "blocks": [
          {
            "name": "A",
            "task": {
              "jobs": []
            }
          }
        ],
        "name": "A",
        "version": "v1.0"
      })
    })

    it("preserves manually entered auto_cancel fields", () => {
      let wf = new Workflow({yamls: [
        yaml.safeDump({
          "version": "1.0",
          "name": "A",
          "blocks": [{"name": "A"}],
          "hello": "unknown"
        })
      ]})

      let p = wf.pipelines[0]

      p.updateYaml([
        "version: 1.0",
        "name: A",
        "blocks:",
        "  - name: A",
        "auto_cancel:",
        "  running:",
        "    when: true"
      ].join("\n"))

      expect(p.toJson()["auto_cancel"]).to.deep.equal({
        "running": { "when" : true }
      })
    })

    it("preserves unknown stanzas in the YAML", () => {
      let wf = new Workflow({yamls: [
        yaml.safeDump({
          "version": "1.0",
          "name": "A",
          "blocks": [{"name": "A"}],
          "hello": "unknown"
        })
      ]})

      let p = wf.pipelines[0]

      expect(p.toJson()["hello"]).to.equal("unknown")
    })
  })

  describe("#toYaml", () => {
    // workflow model mock object
    let wf = {afterUpdate: () => null}

    describe("preserving newline type of the initial yaml", () => {
      describe("when the initial yaml has only CRLF", () => {
        it("generates the new yaml with CRLF", () => {
          let p = new Pipeline(wf, "version: v1.0\r\nname: P2\r\nblocks: []\r\n")

          expect(p.lineEndingInInitialYaml).to.equal("\r\n")

          expect(p.toYaml()).to.equal([
            "version: v1.0",
            "name: P2",
            "agent:",
            "  machine:",
            "    type: e1-standard-2",
            "    os_image: ubuntu2004",
            "blocks: []",
            ""
          ].join("\r\n"))
        })
      })

      describe("when the initial yaml has only LF", () => {
        it("generates the new yaml with LF", () => {
          let p = new Pipeline(wf, "version: v1.0\nname: P2\nblocks: []\n")

          expect(p.lineEndingInInitialYaml).to.equal("\n")

          expect(p.toYaml()).to.equal([
            "version: v1.0",
            "name: P2",
            "agent:",
            "  machine:",
            "    type: e1-standard-2",
            "    os_image: ubuntu2004",
            "blocks: []",
            ""
          ].join("\n"))
        })
      })

      describe("when the initial yaml has more LF than CRLF", () => {
        it("generates then new yaml with LF", () => {
          let p = new Pipeline(wf, "version: v1.0\r\nname: P2\nblocks: []\n")

          expect(p.lineEndingInInitialYaml).to.equal("\n")

          expect(p.toYaml()).to.equal([
            "version: v1.0",
            "name: P2",
            "agent:",
            "  machine:",
            "    type: e1-standard-2",
            "    os_image: ubuntu2004",
            "blocks: []",
            ""
          ].join("\n"))
        })
      })

      describe("when the initial yaml has more CRLF than LF", () => {
        it("generates then new yaml with CRLF", () => {
          let p = new Pipeline(wf, "version: v1.0\r\nname: P2\nblocks: []\r\n")

          expect(p.lineEndingInInitialYaml).to.equal("\r\n")

          expect(p.toYaml()).to.equal([
            "version: v1.0",
            "name: P2",
            "agent:",
            "  machine:",
            "    type: e1-standard-2",
            "    os_image: ubuntu2004",
            "blocks: []",
            ""
          ].join("\r\n"))
        })
      })

      describe("when the initial yaml has equal LF and CRLF", () => {
        it("generates then new yaml with LF", () => {
          let p = new Pipeline(wf, "version: v1.0'\r\nname: P2\n\r\nblocks: []\n")

          expect(p.lineEndingInInitialYaml).to.equal("\n")

          expect(p.toYaml()).to.equal([
            "version: v1.0",
            "name: P2",
            "agent:",
            "  machine:",
            "    type: e1-standard-2",
            "    os_image: ubuntu2004",
            "blocks: []",
            ""
          ].join("\n"))
        })
      })
    })
  })

  describe("#addPromotion", () => {
    it("creates a new promotion with incremental names", () => {
      let wf = new Workflow({yamls: [
        yaml.safeDump({
          "version": "1.0",
          "name": "A",
          "blocks": [{"name": "A"}]
        })
      ]})

      let p = wf.pipelines[0]

      expect(p.toJson().promotions).to.equal(undefined)

      p.addPromotion()

      expect(p.toJson().promotions).to.deep.equal([
        {
          "name": "Promotion 1",
          "pipeline_file": "pipeline_2.yml"
        }
      ])

      p.addPromotion()

      expect(p.toJson().promotions).to.deep.equal([
        {
          "name": "Promotion 1",
          "pipeline_file": "pipeline_2.yml"
        },
        {
          "name": "Promotion 2",
          "pipeline_file": "pipeline_3.yml"
        }
      ])
    })
  })

})
