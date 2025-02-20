import $ from "jquery";

import { JobsConfig } from "./jobs"
import { Utils } from "./utils"

export class AfterPipelineConfigurator {
  constructor(parent, outputDivSelector) {
    this.parent = parent
    this.outputDivSelector = outputDivSelector

    this.jobsConfig = new JobsConfig(this)
    this.renderingDisabled = false
  }

  on(event, selector, callback) {
    this.parent.on(event, `[data-type=afterPipeline] ${selector}`, callback)
  }

  noRender(cb) {
    try {
      this.renderingDisabled = true
      cb()
    } finally {
      this.renderingDisabled = false
    }
  }

  render(afterPipeline) {
    if(this.renderingDisabled) return;

    Utils.preserveScrollPositions(this.outputDivSelector, () => {
      Utils.preserveDropdownState(this.outputDivSelector, () => {
        this.model = afterPipeline

        let html = `
          ${this.renderTitle()}
          ${this.jobsConfig.render()}
        `

        $(this.outputDivSelector).html(html)
      })
    })

    $(this.outputDivSelector).find('textarea').each((_index, el) => {
      this.parent.resizeTextAreaToFitText(el)
    })
  }

  renderTitle() {
    return `
      <div class="bb b--lighter-gray pa3">
        <label class="db f4 b">After Pipeline Jobs</label>

        <p class="f5 mb0">
          Cleanup tasks, publishing metrics, collecting test-results&hellip;
        </p>
      </div>
    `
  }
}
