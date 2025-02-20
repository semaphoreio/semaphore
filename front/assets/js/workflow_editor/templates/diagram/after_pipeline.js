const docsLink = "https://docs.semaphoreci.com/reference/pipeline-yaml-reference/#after_pipeline"

import { SelectionRegister } from "../../selection_register"
import { Job } from "./job"

export class AfterPipeline {

  static render(pipeline) {
    return `<div class="pa3 bb b--black-075">
      ${this.renderTitle()}

      ${pipeline.afterPipeline.isDefined() ?
          this.renderJobs(pipeline) :
          this.renderZeroState(pipeline)}
    </div>`
  }

  static renderTitle() {
    return `
      <div class="mb1 nt1">
        <div class="flex justify-between mb1">
          <label class="f4 normal gray mb0 pb0">After Pipeline Jobs</label>

          <a href="${docsLink}" target="_blank" rel="noopener" class="f6 gray default-tip" data-tippy="" data-original-title="Help: What are after pipeline jobs?">?</a>
        </div>
      </div>
    `
  }

  static renderZeroState(pipeline) {
    return `
      <div data-action=configureAfterPipeline data-pipeline-uid=${pipeline.uid} class="f4 mt2 dib v-top w-100 ba b--dashed bw1 mid-gray hover-dark-gray ph3 pv1 br2 pointer">+ Add After Jobs</div>
    `
  }

  static renderJobs(pipeline) {
    let jobs = pipeline.afterPipeline.jobs.map((j, i) => Job.render(j, i === 0)).join("")

    let selected = this.isSelected(pipeline.afterPipeline) ? "wf-edit-selected" : ""

    return `
      <div data-action="editAfterPipeline" data-pipeline-uid="${pipeline.uid}" class="mt3 bg-white shadow-1 br2 pointer">
        <div class="f5 ph2 br2 pointer ${selected} ${pipeline.afterPipeline.jobs.length > 1 ? "pv1" : ""}">
          ${jobs}
        </div>
      </div>
    `
  }

  static isSelected(afterPipeline) {
    return SelectionRegister.getCurrentSelectionUid() === afterPipeline.uid
  }

}
