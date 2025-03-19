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
      let wrongSchemaYaml = `
versioon: 1.0
name: A
blockks:
  - name: A`

      beforeEach(() => {
        wf = new Workflow({yamls: [
          yaml.safeDump({
            "version": "v1.0",
            "name": "Initial Pipeline",
            "agent": {
              "machine": {
                "type": "f1-standard-2",
                "os_image": "ubuntu2204"
              }
            },
            "blocks": [
              {
                "name": "Block #1",
                "task": {
                  "jobs": [
                    {
                      "name": "Job #1",
                      "commands": [
                        "checkout"
                      ]
                    }
                  ]
                }
              }
            ]
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
        ppl.updateYaml(brokenYaml)

        expect(ppl.hasInvalidYaml()).to.equal(true)
      })

      it ("has invalid Schema", () => {
        expect(ppl.hasSchemaErrors()).to.equal(false)

        ppl.updateYaml(wrongSchemaYaml)

        expect(ppl.hasSchemaErrors()).to.equal(true)
      });

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

  describe("#validateSchema", () => {
    it("validates the schema", () => {
      let wf = new Workflow({yamls: [
        yaml.safeDump({
          "version": "v1.0",
          "name": "Initial Pipeline",
          "agent": {
            "machine": {
              "type": "f1-standard-2",
              "os_image": "ubuntu2204"
            }
          },
          "blocks": [
            {
              "name": "Block #1",
              "task": {
                "jobs": [
                  {
                    "name": "Job #1",
                    "commands": [
                      "checkout"
                    ]            
                  }
                ]
              }
            }
          ]
        })
      ]})

      let p = wf.pipelines[0]

      p.validateSchema()

      expect(p.schemaErrors).to.deep.equal([])
    })

    it("validates the schema with invalid schema", () => {
      let wf = new Workflow({yamls: [
        yaml.safeDump({
          "version": "1.0",
          "name": "A",
          "agent": {
            "machine": {
              "type": "e1-standard-2",
              "os_image": "ubuntu2004"
            }
          },
          "blocks": [{"name": "A"}]
        })
      ]})

      let p = wf.pipelines[0]

      p.updateYaml(
`version: v1.0
name: Initial Pipeline
agent:
  machine:
    typppe: f1-standard-2
    os_image: ubuntu2204
blocks:
  - name: 'Block #1'
    task:
      jobs:
        - nameeeee: 'Job #1'
          commanddddds:
            - checkout
`)

      p.validateSchema()

      expect(p.schemaErrors).to.deep.equal([
        {
          instancePath: '/agent/machine',
          schemaPath: '#/properties/machine/required',
          keyword: 'required',
          params: { missingProperty: 'type' },
          message: "must have required property 'type'",
          line: 3,
          column: 1
        },
        {
          instancePath: '/agent/machine',
          schemaPath: '#/properties/machine/additionalProperties',
          keyword: 'additionalProperties',
          params: { additionalProperty: 'typppe' },
          message: 'must NOT have additional properties',
          line: 5,
          column: 5
        },
        {
          instancePath: '/blocks/0/task/jobs/0',
          schemaPath: '#/oneOf/0/required',
          keyword: 'required',
          params: { missingProperty: 'commands' },
          message: "must have required property 'commands'",
          line: 10,
          column: 7
        },
        {
          instancePath: '/blocks/0/task/jobs/0',
          schemaPath: '#/oneOf/1/required',
          keyword: 'required',
          params: { missingProperty: 'commands_file' },
          message: "must have required property 'commands_file'",
          line: 10,
          column: 7
        },
        {
          instancePath: '/blocks/0/task/jobs/0',
          schemaPath: '#/additionalProperties',
          keyword: 'additionalProperties',
          params: { additionalProperty: 'nameeeee' },
          message: 'must NOT have additional properties',
          line: 11,
          column: 11
        },
        {
          instancePath: '/blocks/0/task/jobs/0',
          schemaPath: '#/additionalProperties',
          keyword: 'additionalProperties',
          params: { additionalProperty: 'commanddddds' },
          message: 'must NOT have additional properties',
          line: 12,
          column: 11
        }
      ])
    })
  })
})
