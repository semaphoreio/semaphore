import { Section } from "./section"
import { AgentConfig } from "./agent"

export class PipelineConfigTempate {

  static agent(pipeline) {
    let options = {
      title: "Agent",
      collapsable: false
    }

    return Section.section(options, `
      <div class="mt2">
        ${AgentConfig.render(pipeline.agent)}
      </div>
    `)
  }

  static executionTimeLimit(pipeline) {
    let status = null
    let value = pipeline.executionTimeLimit.getValue()

    if(pipeline.executionTimeLimit.getUnit() === "hours") {
      if(value === 1) {
        status = value + " hour"
      } else if(value > 1) {
        status = value + " hours"
      }
    }

    if(pipeline.executionTimeLimit.getUnit() === "minutes") {
      if(value === 1) {
        status = value + " minute"
      } else if(value > 1) {
        status = value + " minutes"
      }
    }

    let options = {
      title: "Execution time limit",
      status: status,
      collapsable: true
    }

    return Section.section(options, `
      <p class="f5 mb2">Stop the pipeline when over the limit</p>

      <div class="flex">
        <input data-action=changePipelineExecutionTimeLimit
               id="execution-time-limit"
               type="text"
               autocomplete="off"
               class="w-25 form-control form-control-small mr2"
               placeholder="Limit…"
               value="${pipeline.executionTimeLimit.getValue()}">

        <div class="w-75">
          <select data-action=changePipelineExecutionTimeLimit class="form-control form-control-small w-100">
            <option value="hours"   ${pipeline.executionTimeLimit.getUnit() === "hours" ? "selected=selected" : ""}>Hours</option>
            <option value="minutes" ${pipeline.executionTimeLimit.getUnit() === "minutes" ? "selected=selected" : ""}>Minutes</option>
          </select>
        </div>
    `)
  }

  static name(pipeline) {
    let options = {
      title: "Name of the Pipeline",
      errorSubtitles: pipeline.errors.list("name")
    }

    return Section.section(options, `
      <input type="text"
             data-action=changePipelineName
             id="pipeline-name"
             autocomplete="off"
             class="form-control form-control-small w-100"
             placeholder="Enter Name…"
             value="${escapeHtml(pipeline.name)}">
    `)
  }

  static path(pipeline) {
    let options = {
      title: "YAML file path",
      errorSubtitles: pipeline.errors.list("path"),
      collapsable: true
    }

    return Section.section(options, `
      <p class="f5 gray mb2">Path in Git repository</p>

      <input type="text"
             data-action=changeFilePath
             id="pipeline-name"
             class="form-control form-control-small w-100"
             placeholder="Enter Path…"
             ${pipeline.filePath === pipeline.workflow.initialYAMLPath ? "disabled" : ""}
             value="${escapeHtml(pipeline.filePath)}">
    `)
  }

  static deletePipeline(pipeline) {
    if(pipeline.filePath === pipeline.workflow.initialYAMLPath) {
      return `<div class="bb b--lighter-gray tc">
        <p class="gray link db pa3 mb0">Delete Pipeline…</p>
      </div>`
    } else {
      return `<div class="bb b--lighter-gray tc">
        <a data-action=deletePipeline href="#" class="link db red pa3">Delete Pipeline…</a>
      </div>`
    }
  }
}
