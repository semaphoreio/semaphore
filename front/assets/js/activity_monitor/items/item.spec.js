import { expect } from "chai"
import { Item } from "./item"

describe("Item", () => {

  describe(".jobSummary", () => {
    it("displays counts", () => {
      let item = {
        job_stats: {
          left: 3,
          running: {job_count: 10},
          waiting: {job_count: 2}
        }
      }

      expect(Item.jobSummary(item)).to.include("10 Jobs running")
      expect(Item.jobSummary(item)).to.include("+ 2 waiting")
      expect(Item.jobSummary(item)).to.include("+ 3 left")
    })

    describe("only running", () => {
      it("displays a runing badge", () => {
        let item = {
          job_stats: {
            running: {job_count: 10},
            waiting: {job_count: 0}
          }
        }

        expect(Item.jobSummary(item)).to.include("10 Jobs running")
        expect(Item.jobSummary(item)).to.not.include("waiting")
        expect(Item.jobSummary(item)).to.not.include("left")
      })
    })

    describe("only waiting", () => {
      it("displays a runing badge", () => {
        let item = {
          job_stats: {
            running: {job_count: 0},
            waiting: {job_count: 10}
          }
        }

        expect(Item.jobSummary(item)).to.include("10 Jobs waiting")
        expect(Item.jobSummary(item)).to.not.include("running")
        expect(Item.jobSummary(item)).to.not.include("left")
      })
    })

    describe("only left", () => {
      it("displays a runing badge", () => {
        let item = {
          job_stats: {
            left: 10,
            running: {job_count: 0},
            waiting: {job_count: 0}
          }
        }

        expect(Item.jobSummary(item)).to.include("10 Jobs left")
        expect(Item.jobSummary(item)).to.not.include("running")
        expect(Item.jobSummary(item)).to.not.include("waiting")
      })
    })
  })

  describe(".jobSummaryDescription", () => {
    describe("when only one agent type is used", () => {
      it("displays only one job type", () => {
        let item = {
          job_stats: {
            running: {machine_types: {"e1-standard-2": 2}},
            waiting: {machine_types: {"e1-standard-2": 1}}
          }
        }

        expect(Item.jobSummaryDescription(item)).to.equal("on e1-standard-2")
      })
    })

    describe("when agent types are mixed and every agent has waiting and running jobs", () => {
      it("displays a fuller description", () => {
        let item = {
          job_stats: {
            running: {machine_types: {"e1-standard-2": 1, "e1-standard-4": 2}},
            waiting: {machine_types: {"e1-standard-2": 1, "e1-standard-4": 1}}
          }
        }

        expect(Item.jobSummaryDescription(item)).to.equal("on e1-standard-2 (1 running, 1 waiting), e1-standard-4 (2 running, 1 waiting)")
      })
    })

    describe("when agent types are mixed and some agents have waiting and some only running jobs", () => {
      it("displays a fuller description", () => {
        let item = {
          job_stats: {
            running: {machine_types: {"e1-standard-2": 1, "e1-standard-4": 2}},
            waiting: {machine_types: {"e1-standard-2": 1, "e1-standard-8": 10}}
          }
        }

        expect(Item.jobSummaryDescription(item)).to.equal("on e1-standard-2 (1 running, 1 waiting), e1-standard-4 (2 running), e1-standard-8 (10 waiting)")
      })
    })

    describe("when no agents are used (transition states)", () => {
      it("displays nothing", () => {
        let item = {
          job_stats: {
            running: {machine_types: {}},
            waiting: {machine_types: {}}
          }
        }

        expect(Item.jobSummaryDescription(item)).to.equal("")
      })
    })
  })

})
