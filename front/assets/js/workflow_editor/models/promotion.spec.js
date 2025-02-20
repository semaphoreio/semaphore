import yaml from "js-yaml"
import _ from "lodash"

import { expect } from "chai"
import { Workflow } from "./workflow"
import { Agent } from "./agent"

describe("Promotion", () => {

  Agent.setupTestAgentTypes();

  describe("#toJson", () => {
    describe("pipeline file is not defined", () => {
      it("doesn't try to ", () => {
        let wf = new Workflow({
          yamls: [
            yaml.safeDump({
              "version": "1.0",
              "blocks": [{ "name": "A" }],
              "promotions": [
                {
                  "name": "A"
                }
              ]
            })
          ]
        })

        let promotion = wf.pipelines[0].promotions[0]

        expect(_.has(promotion.toJson(), "pipeline_file")).to.equal(false)
      })
    })
  })

  describe("#targetPipelineFilename", () => {
    describe("targetPipelineFile is relative", () => {
      it("appends to the directory", () => {
        let wf = new Workflow({
          yamls: {
            '.semaphore/semaphore.yml': yaml.safeDump({
              "version": "1.0",
              "blocks": [{ "name": "A" }],
              "promotions": [
                {
                  "name": "A",
                  "pipeline_file": "build/prod.yml"
                }
              ]
            })
          }
        })

        let promotion = wf.pipelines[0].promotions[0]

        expect(promotion.targetPipelineFilename()).to.equal(".semaphore/build/prod.yml")
      })

      it("preserves the nesting level", () => {
        let wf = new Workflow({
          yamls: {
            '.semaphore/stage1/index.yml': yaml.safeDump({
              "version": "1.0",
              "blocks": [{ "name": "A" }],
              "promotions": [
                {
                  "name": "A",
                  "pipeline_file": "build/prod.yml"
                }
              ]
            })
          }
        })

        let promotion = wf.pipelines[0].promotions[0]

        expect(promotion.targetPipelineFilename()).to.equal(".semaphore/stage1/build/prod.yml")
      })
    })
  })


  describe("#targetPipelineFilename", () => {
    describe("targetPipelineFile is absolute", () => {
      it("appends to the directory", () => {
        let wf = new Workflow({
          yamls: {
            '.semaphore/semaphore.yml': yaml.safeDump({
              "version": "1.0",
              "blocks": [{ "name": "A" }],
              "promotions": [
                {
                  "name": "A",
                  "pipeline_file": "/.semaphore/prod.yml"
                }
              ]
            })
          }
        })

        let promotion = wf.pipelines[0].promotions[0]

        expect(promotion.targetPipelineFilename()).to.equal(".semaphore/prod.yml")
      })

      it("preserves the nesting level", () => {
        let wf = new Workflow({
          yamls: {
            '.semaphore/stage1/index.yml': yaml.safeDump({
              "version": "1.0",
              "blocks": [{ "name": "A" }],
              "promotions": [
                {
                  "name": "A",
                  "pipeline_file": "/build/prod.yml"
                }
              ]
            })
          }
        })

        let promotion = wf.pipelines[0].promotions[0]

        expect(promotion.targetPipelineFilename()).to.equal("build/prod.yml")
      })
    })
  })
})
