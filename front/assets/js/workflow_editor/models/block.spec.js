import yaml from "js-yaml"

import { expect } from "chai"
import { Workflow } from "./workflow"
import { Block } from "./block"
import { Agent } from "./agent"

describe("Block", () => {

  Agent.setupTestAgentTypes();

  let parent = { afterUpdate: () => {} }

  describe("constructor", () => {
    it("parses epilogue commands", () => {
      let b = new Block(parent, {
        "name": "A",
        "task": {
          "epilogue": {
            "always":  { "commands": ["echo A"] },
            "on_fail": { "commands": ["echo C"] },
            "on_pass": { "commands": ["echo B"] }
          }
        }
      })

      expect(b.toJson()).to.deep.equal({
        "name": "A",
        "task": {
          "jobs": [],
          "epilogue": {
            "always":  { "commands": ["echo A"] },
            "on_fail": { "commands": ["echo C"] },
            "on_pass": { "commands": ["echo B"] }
          }
        }
      })
    })

    it("parses prologue commands", () => {
      let b = new Block(parent, {
        "name": "A",
        "task": {
          "prologue": {
            "commands": ["echo A"],
          }
        }
      })

      expect(b.toJson()).to.deep.equal({
        "name": "A",
        "task": {
          "jobs": [],
          "prologue": {
            "commands": ["echo A"],
          }
        }
      })
    })

    it("parses skip conditions", () => {
      let b = new Block(parent, {
        "name": "A",
        "skip": {
          "when": "branch = 'master'"
        }
      })

      expect(b.skipCondition).to.equal("branch = 'master'")
      expect(b.hasSkipConditions()).to.equal(true)
      expect(b.hasConditionForRunning()).to.equal(true)

      expect(b.toJson()).to.deep.equal({
        "name": "A",
        "skip": {"when": "branch = 'master'"},
        "task": {"jobs": []}
      })
    })

    it("parses run conditions", () => {
      let b = new Block(parent, {
        "name": "A",
        "run": {
          "when": "branch = 'dev'"
        }
      })

      expect(b.runCondition).to.equal("branch = 'dev'")
      expect(b.hasRunConditions()).to.equal(true)
      expect(b.hasConditionForRunning()).to.equal(true)

      expect(b.toJson()).to.deep.equal({
        "name": "A",
        "run": {"when": "branch = 'dev'"},
        "task": {"jobs": []}
      })
    })
  })

  describe("validations", () => {
    describe("name", () => {
      it("validates that names are non-empty", () => {
        let wf = new Workflow({yamls: [
          yaml.safeDump({
            "version": "1.0",
            "blocks": [{"name": ""}]
          })
        ]})

        let b = wf.pipelines[0].blocks[0]

        b.validate()

        expect(b.errors.list("name")).to.deep.equal([
          "Block name can't be blank."
        ])

        b.changeName("A")
        b.validate()

        expect(b.errors.list("name")).to.deep.equal([])
      })

      it("validates name uniqueness", () => {
        let wf = new Workflow({yamls: [
          yaml.safeDump({
            "version": "1.0",
            "blocks": [{"name": "A"}, {"name": "A"}]
          })
        ]})

        let b = wf.pipelines[0].blocks[1]
        b.validate()

        expect(b.errors.list("name")).to.deep.equal([
          "Name must be unique in pipeline."
        ])

        b.changeName("B")
        b.validate()

        expect(b.errors.list("name")).to.deep.equal([])
      })
    })
  })

  describe("#addJob", () => {
    let block = null;

    beforeEach(() => {
      let pipeline1 = yaml.safeDump({
        "version": "1.0",
        "blocks": [
          {
            "name": "A",
            "task": {
              "jobs": [
                {
                  "name": "A",
                  "commands": []
                }
              ]
            }
          }
        ]
      })

      let wf = new Workflow({yamls: [pipeline1]})
      block = wf.pipelines[0].blocks[0]
    })

    it("adds a new job with the specified structure", () => {
      block.addJob({
        name: "B",
        commands: ["echo here"]
      })

      expect(block.jobs.length).to.equal(2)
      expect(block.jobs[1].name).to.equal("B")
      expect(block.jobs[1].commands).to.deep.equal(["echo here"])
    })
  })

  describe("#changeName", () => {
    it("does not break block dependencies", () => {
      let pipeline = yaml.safeDump({
        "version": "1.0",
        "blocks": [
          {"name": "A", dependencies: []},
          {"name": "B", dependencies: ["A"]},
          {"name": "C", dependencies: ["A"]}
        ]
      })

      let wf = new Workflow({yamls: [pipeline]})

      expect(wf.pipelines[0].blocks[1].dependencies.listNames()).to.deep.equal(["A"])
      expect(wf.pipelines[0].blocks[2].dependencies.listNames()).to.deep.equal(["A"])

      wf.pipelines[0].blocks[0].changeName("AAA")

      expect(wf.pipelines[0].blocks[1].dependencies.listNames()).to.deep.equal(["AAA"])
      expect(wf.pipelines[0].blocks[2].dependencies.listNames()).to.deep.equal(["AAA"])
    })
  })

  describe("#dependencyIntroducesCycle", () => {
    let wf = null;

    beforeEach(() => {
      //
      // A -> B -> C
      // D
      //
      let pipeline1 = yaml.safeDump({
        "version": "1.0",
        "blocks": [
          {
            "name": "A",
            "dependencies": [],
            "task": {"jobs": [{"name": "A", "commands": []}]}
          },
          {
            "name": "B",
            "dependencies": ["A"],
            "task": {"jobs": [{"name": "A", "commands": []}]}
          },
          {
            "name": "C",
            "dependencies": ["B"],
            "task": {"jobs": [{"name": "A", "commands": []}]}
          },
          {
            "name": "D",
            "dependencies": [],
            "task": {"jobs": [{"name": "A", "commands": []}]}
          },
        ]
      })

      wf = new Workflow({yamls: [pipeline1]})
    })

    describe("new edge would introduce a cycle", () => {
      it("returns true", () => {
        //
        // A -> B -> C
        // |         |
        // ^---------|
        //
        // D
        //

        let blockA = wf.pipelines[0].blocks[0]
        let blockC = wf.pipelines[0].blocks[2]

        expect(blockA.dependencyIntroducesCycle(blockC)).to.equal(true)
      })
    })

    describe("new edge doesn't introduces a cycle", () => {
      it("returns false", () => {
        //
        // A -> B -> C -> D
        //

        let blockD = wf.pipelines[0].blocks[3]
        let blockC = wf.pipelines[0].blocks[2]

        expect(blockD.dependencyIntroducesCycle(blockC)).to.equal(false)
      })
    })
  })

  describe("#changeOverrideGlobalAgent", () => {
    let block = null

    beforeEach(() => {
      let pipeline1 = yaml.safeDump({
        "version": "1.0",
        "blocks": [
          {
            "name": "A",
            "task": {"jobs": [{"name": "A", "commands": []}]}
          },
        ]
      })

      let wf = new Workflow({yamls: [pipeline1]})
      block = wf.pipelines[0].blocks[0]
    })

    describe("setting it to enabled", () => {
      beforeEach(() => {
        block.changeOverrideGlobalAgent(true)
      })

      it("renders agents in the JSON", () => {
        expect(block.toJson()).to.deep.equal({
          "name": "A",
          "task": {
            "agent": {
              "machine": {
                "os_image": "ubuntu2004",
                "type": "e1-standard-2"
              }
            },
            "jobs": [
              {
                "commands": [],
                "name": "A"
              }
            ]
          }
        })
      })

      it("sets the overrideGlobalAgent to true", () => {
        expect(block.overrideGlobalAgent).to.equal(true)
      })
    })

    describe("setting it to disabled", () => {
      beforeEach(() => {
        block.changeOverrideGlobalAgent(false)
      })

      it("renders agents in the JSON", () => {
        expect(block.toJson()).to.deep.equal({
          "name": "A",
          "task": {
            "jobs": [
              {
                "commands": [],
                "name": "A"
              }
            ]
          }
        })
      })

      it("sets the overrideGlobalAgent to true", () => {
        expect(block.overrideGlobalAgent).to.equal(false)
      })
    })
  })

  describe("#clearConditionsForRunning", () => {
    it("clears run condition", () => {
      let b = new Block(parent, {"name": "A", "run": {"when": "branch = 'dev'"} })

      expect(b.runCondition).to.equal("branch = 'dev'")
      b.clearConditionsForRunning()
      expect(b.runCondition).to.equal("")
    })

    it("clears skip condition", () => {
      let b = new Block(parent, {"name": "A", "skip": {"when": "branch = 'dev'"} })

      expect(b.skipCondition).to.equal("branch = 'dev'")
      b.clearConditionsForRunning()
      expect(b.skipCondition).to.equal("")
    })

  })

  describe("#setRunConditions", () => {
    it("sets run condition", () => {
      let b = new Block(parent, {"name": "A", "run": {"when": "branch = 'dev'"} })

      expect(b.runCondition).to.equal("branch = 'dev'")
      b.setRunConditions("change_in('lib')")
      expect(b.runCondition).to.equal("change_in('lib')")
    })

    it("clears skip condition", () => {
      let b = new Block(parent, {"name": "A", "skip": {"when": "branch = 'dev'"} })

      expect(b.skipCondition).to.equal("branch = 'dev'")

      b.setRunConditions("change_in('lib')")
      expect(b.skipCondition).to.equal("")
      expect(b.runCondition).to.equal("change_in('lib')")
    })
  })

  describe("#setSkipConditions", () => {
    it("sets skip condition", () => {
      let b = new Block(parent, {"name": "A", "skip": {"when": "branch = 'dev'"} })

      expect(b.skipCondition).to.equal("branch = 'dev'")
      b.setSkipConditions("change_in('lib')")
      expect(b.skipCondition).to.equal("change_in('lib')")
    })

    it("clears skip condition", () => {
      let b = new Block(parent, {"name": "A", "run": {"when": "branch = 'dev'"} })

      expect(b.runCondition).to.equal("branch = 'dev'")

      b.setSkipConditions("change_in('lib')")
      expect(b.runCondition).to.equal("")
      expect(b.skipCondition).to.equal("change_in('lib')")
    })
  })
})
