import yaml from "js-yaml"

import { expect } from "chai"
import { Workflow } from "./workflow"
import { Job } from "./job"
import { Agent } from "./agent"

describe("Job", () => {

  Agent.setupTestAgentTypes();

  describe("constructor", () => {
    describe("when the name is not set", () => {
      it("sets the name to Nameless <index>", () => {
        let wf = new Workflow({yamls: [
          yaml.safeDump({
            "version": "1.0",
            "blocks": [{
              "name": "A",
              "task": {
                "jobs": [
                  {
                    "commands": ["echo A"]
                  }
                ]
              }
            }]
          })
        ]})

        let job = wf.pipelines[0].blocks[0].jobs[0]

        expect(job.name).to.equal("Nameless 1")
      })
    })

    describe("parallelism", () => {
      let block = { afterUpdate: () => {} }

      describe("when it is not set", () => {
        it("sets the value to null", () => {
          let job = new Job(block, 0, {
            name: "A"
          })

          expect(job.parallelism).to.equal(null)
        })
      })

      describe("when it is set", () => {
        it("parses and stores the value", () => {
          let job = new Job(block, 0, {
            name: "A",
            parallelism: 10
          })

          expect(job.parallelism).to.equal(10)
        })
      })
    })

    describe("matrix", () => {
      let block = { afterUpdate: () => {} }

      describe("when it is not set", () => {
        it("sets the value to null", () => {
          let job = new Job(block, 0, {
            name: "A"
          })

          expect(job.matrix).to.equal(null)
        })
      })

      describe("when it is set", () => {
        it("parses and stores the value", () => {
          let job = new Job(block, 0, {
            name: "A",
            matrix: [
              {env_var: "A", values: ["1", "2"]},
              {env_var: "B", values: ["3", "4"]}
            ]
          })

          expect(job.matrix).to.deep.equal([
            {env_var: "A", values: ["1", "2"]},
            {env_var: "B", values: ["3", "4"]}
          ])
        })
      })
    })
  })

  describe("validate", () => {
    let block = { afterUpdate: () => {} }

    describe("when parallelism is a negative number", () => {
      it("adds an error", () => {
        let job = new Job(block, 0, {
          name: "A",
          parallelism: 10
        })

        job.changeParallelism(-10)
        job.validate()

        expect(job.errors.list("parallelism")).to.deep.equal([
          "Parallelism must be larger than 0"
        ])
      })
    })
  })

  describe("toJson", () => {
    let block = { afterUpdate: () => {} }

    describe("parallelism", () => {
      describe("when the initial structure had parallelism, but it was removed while editing", () => {
        it("removes the parallelism keyword from output", () => {
          let job = new Job(block, 0, {
            name: "A",
            parallelism: 10
          })

          job.disableParallelism()

          expect(job.toJson()).to.deep.equal({
            name: "A",
            commands: []
          })
        })
      })
    })

    describe("matrix", () => {
      describe("when matrix is present", () => {
        it("outputs matrix in the json", () => {
          let job = new Job(block, 0, {name: "A"})

          job.changeMatrix({env_var: "A", values: ["1"]})

          expect(job.toJson()).to.deep.equal({
            name: "A",
            commands: [],
            matrix: {
              env_var: "A",
              values: ["1"]
            }
          })
        })
      })

      describe("when the initial structure had matrix, but it was removed while editing", () => {
        it("removes the matrix keyword from output", () => {
          let job = new Job(block, 0, {
            name: "A",
            matrix: [
              {env_var: "A", values: ["1", "2"]}
            ]
          })

          job.disableMatrix()

          expect(job.toJson()).to.deep.equal({
            name: "A",
            commands: []
          })
        })
      })
    })
  })

})
