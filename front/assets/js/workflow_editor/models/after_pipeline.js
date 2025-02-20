import _ from "lodash"

import { SelectionRegister } from "../selection_register"
import { Job } from "./job"

export class AfterPipeline {
  constructor(pipeline, structure) {
    this.pipeline = pipeline
    this.structure = structure || {}

    this.uid = SelectionRegister.add(this)
    this.modelName = "after_pipeline"

    this.jobs = (_.get(this.structure, ["task", "jobs"]) || []).map((j, i) => new Job(this, i, j))
  }

  addJob(structure) {
    let j = new Job(this, this.jobs.length, structure)

    this.jobs.push(j)
    this.afterUpdate()

    return j
  }

  removeJobByIndex(jobIndex) {
    this.jobs.splice(jobIndex, 1)
    this.afterUpdate()
  }

  afterUpdate() {
    this.pipeline.afterUpdate()
  }

  isDefined() {
    return this.jobs.length > 0
  }

  toJson() {
    let res = _.cloneDeep(this.structure)

    res["task"] = res.task || {}

    res["task"]["jobs"] = this.jobs.map(j => j.toJson())

    return res
  }
}
