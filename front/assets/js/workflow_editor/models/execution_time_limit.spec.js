import yaml from "js-yaml"

import { expect } from "chai"
import { Workflow } from "./workflow"
import { Agent } from "./agent"

describe("ExecutionTimeLimit", () => {

  Agent.setupTestAgentTypes();

  describe("#constructor", () => {
    describe("when the limit is defined as hours", () => {
      let ppl = null;

      beforeEach(() => {
        let pipeline1 = yaml.safeDump({
          "version": "1.0",
          "execution_time_limit": {
            "hours": 60
          },
          "blocks": []
        })

        let wf = new Workflow({yamls: [pipeline1]})
        ppl = wf.pipelines[0]
      })

      it("sets isDefined to true", () => {
        expect(ppl.executionTimeLimit.isDefined()).to.equal(true)
      })

      it("sets unit to unit from structure", () => {
        expect(ppl.executionTimeLimit.getUnit()).to.equal("hours")
      })

      it("sets value to unit from structure", () => {
        expect(ppl.executionTimeLimit.getValue()).to.equal(60)
      })

      it("can dump a valid json", () => {
        expect(ppl.executionTimeLimit.toJson()).to.deep.equal({
          "hours": 60
        })
      })
    })

    describe("when the limit is defined as minutes", () => {
      let ppl = null;

      beforeEach(() => {
        let pipeline1 = yaml.safeDump({
          "version": "1.0",
          "execution_time_limit": {
            "minutes": 6
          },
          "blocks": []
        })

        let wf = new Workflow({yamls: [pipeline1]})
        ppl = wf.pipelines[0]
      })

      it("sets isDefined to true", () => {
        expect(ppl.executionTimeLimit.isDefined()).to.equal(true)
      })

      it("sets unit to unit from structure", () => {
        expect(ppl.executionTimeLimit.getUnit()).to.equal("minutes")
      })

      it("sets value to unit from structure", () => {
        expect(ppl.executionTimeLimit.getValue()).to.equal(6)
      })

      it("can dump a valid json", () => {
        expect(ppl.executionTimeLimit.toJson()).to.deep.equal({
          "minutes": 6
        })
      })
    })

    describe("when the limit is not defined", () => {
      let ppl = null;

      beforeEach(() => {
        let pipeline1 = yaml.safeDump({
          "version": "1.0",
          "blocks": []
        })

        let wf = new Workflow({yamls: [pipeline1]})
        ppl = wf.pipelines[0]
      })

      it("sets isDefined to false", () => {
        expect(ppl.executionTimeLimit.isDefined()).to.equal(false)
      })

      it("sets unit to hours", () => {
        expect(ppl.executionTimeLimit.getUnit()).to.equal("hours")
      })

      it("sets value to 1", () => {
        expect(ppl.executionTimeLimit.getValue()).to.equal(1)
      })
    })
  })
})
