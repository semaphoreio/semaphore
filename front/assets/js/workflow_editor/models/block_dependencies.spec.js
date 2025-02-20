import yaml from "js-yaml"

import { expect } from "chai"
import { Workflow } from "./workflow"
import { Agent } from "./agent"

describe("BlockDependecines", () => {

  Agent.setupTestAgentTypes();

  describe("#constructor", () => {
    describe("when the dependencies are implicit", () => {
      let ppl = null;

      beforeEach(() => {
        let pipeline1 = yaml.safeDump({
          "version": "1.0",
          "execution_time_limit": {
            "hours": 60
          },
          "blocks": [
            {name: "A"},
            {name: "B"},
            {name: "C"}
          ]
        })

        let wf = new Workflow({yamls: [pipeline1]})
        ppl = wf.pipelines[0]
      })

      it("sets the dependency as implicit", () => {
        expect(ppl.blocks[0].dependencies.isImplicit()).to.equal(true)
        expect(ppl.blocks[1].dependencies.isImplicit()).to.equal(true)
        expect(ppl.blocks[2].dependencies.isImplicit()).to.equal(true)
      })

      it("defines dependencies on previous blocks", () => {
        expect(ppl.blocks[0].dependencies.listNames()).to.deep.equal([])
        expect(ppl.blocks[1].dependencies.listNames()).to.deep.equal(["A"])
        expect(ppl.blocks[2].dependencies.listNames()).to.deep.equal(["B"])

        expect(ppl.blocks[0].dependencies.listBlockUids()).to.deep.equal([])
        expect(ppl.blocks[1].dependencies.listBlockUids()).to.deep.equal([ppl.blocks[0].uid])
        expect(ppl.blocks[2].dependencies.listBlockUids()).to.deep.equal([ppl.blocks[1].uid])
      })
    })

    describe("when the dependencies are explicit", () => {
      let ppl = null;

      beforeEach(() => {
        let pipeline1 = yaml.safeDump({
          "version": "1.0",
          "execution_time_limit": {
            "hours": 60
          },
          "blocks": [
            {name: "A", dependencies: []},
            {name: "B", dependencies: ["A"]},
            {name: "C", dependencies: ["A"]}
          ]
        })

        let wf = new Workflow({yamls: [pipeline1]})
        ppl = wf.pipelines[0]
      })

      it("sets the dependency as explicit", () => {
        expect(ppl.blocks[0].dependencies.isImplicit()).to.not.equal(true)
        expect(ppl.blocks[1].dependencies.isImplicit()).to.not.equal(true)
        expect(ppl.blocks[2].dependencies.isImplicit()).to.not.equal(true)
      })

      it("defines dependencies based on initial structure", () => {
        expect(ppl.blocks[0].dependencies.listNames()).to.deep.equal([])
        expect(ppl.blocks[1].dependencies.listNames()).to.deep.equal(["A"])
        expect(ppl.blocks[2].dependencies.listNames()).to.deep.equal(["A"])

        expect(ppl.blocks[0].dependencies.listBlockUids()).to.deep.equal([])
        expect(ppl.blocks[1].dependencies.listBlockUids()).to.deep.equal([ppl.blocks[0].uid])
        expect(ppl.blocks[2].dependencies.listBlockUids()).to.deep.equal([ppl.blocks[0].uid])
      })
    })
  })

  describe("#add", () => {
    describe("when the dependencies are explicit", () => {
      let ppl = null;

      beforeEach(() => {
        let pipeline1 = yaml.safeDump({
          "version": "1.0",
          "execution_time_limit": {
            "hours": 60
          },
          "blocks": [
            {name: "A", dependencies: []},
            {name: "B", dependencies: ["A"]},
            {name: "C", dependencies: ["A"]}
          ]
        })

        let wf = new Workflow({yamls: [pipeline1]})
        ppl = wf.pipelines[0]
      })

      it("adds dependency", () => {
        ppl.blocks[2].dependencies.add("B")

        expect(ppl.blocks[2].dependencies.listNames()).to.deep.equal(["A", "B"])
      })
    })

    describe("when the dependencies are implicit", () => {
      let ppl = null;

      beforeEach(() => {
        let pipeline1 = yaml.safeDump({
          "version": "1.0",
          "execution_time_limit": {
            "hours": 60
          },
          "blocks": [
            {name: "A"},
            {name: "B"},
            {name: "C"}
          ]
        })

        let wf = new Workflow({yamls: [pipeline1]})
        ppl = wf.pipelines[0]
      })

      it("adds dependency", () => {
        ppl.blocks[2].dependencies.add("A")

        expect(ppl.blocks[2].dependencies.listNames()).to.deep.equal(["A", "B"])
      })

      it("makes the dependencies explicit", () => {
        expect(ppl.blocks[2].dependencies.isImplicit()).to.equal(true)

        ppl.blocks[2].dependencies.add("A")

        expect(ppl.blocks[2].dependencies.isImplicit()).to.equal(false)
      })
    })
  })
})
