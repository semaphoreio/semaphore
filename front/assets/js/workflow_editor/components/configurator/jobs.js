import $ from "jquery"
import _ from "lodash"

import { Utils } from "./utils"
import { Section } from "../../templates/configurator/section"
import { SelectionRegister } from "../../selection_register"
import { CSV } from "../../csv"

const PARALLELISM_TYPE_SINGLE_JOB = "single-job"
const PARALLELISM_TYPE_MULTIPLE_JOBS = "multiple-jobs"
const PARALLELISM_TYPE_MATRIX = "matrix"

const DEFAULT_MATRIX_ENV_NAMES = ["FOO", "BAR", "BAZ"]

export class JobsConfig {
  constructor(parent) {
    this.parent = parent

    this.expandedJobs = {}
    this.handleEvents()
  }

  isJobExpanded(index) {
    return this.expandedJobs[index] === true
  }

  expandJob(index) {
    this.expandedJobs[index] = true
  }

  collapseJob(index) {
    delete this.expandedJobs[index]
  }

  handleEvents() {
    this.on("click", "[data-action=deleteJob]", (e) => {
      let jobIndex = Utils.intAttr(e.currentTarget, "data-job-index")
      let parent   = SelectionRegister.getSelectedElement()

      if(parent) {
        let job = parent.jobs[jobIndex]
        let isConfirmed = confirm(`Deleting ${job.name}. Are You sure?`)

        if(isConfirmed) {
          parent.removeJobByIndex(jobIndex)
          this.render()
        }
      }
    })

    let updateCommands = _.debounce((job, newCommands) => {
      this.parent.noRender(() => {
        job.changeCommands(newCommands)
      })
    }, 500)

    this.on("input", "[data-action=changeJobCommands]", (e) => {
      let commands = $(e.currentTarget).val()
      let jobIndex = Utils.intAttr(e.currentTarget, "data-job-index")
      let parent   = SelectionRegister.getSelectedElement()

      updateCommands(parent.jobs[jobIndex], this.parseCommands(commands))
    })

    this.on("input", "[data-action=changeJobName]", (e) => {
      let name     = $(e.currentTarget).val()
      let jobIndex = Utils.intAttr(e.currentTarget, "data-job-index")
      let parent = SelectionRegister.getSelectedElement()

      if(!parent) return;

      this.parent.noRender(() => {
        parent.jobs[jobIndex].changeName(name)
      })
    })

    this.on("click", "[data-action=addNewJob]", () => {
      let parent = SelectionRegister.getSelectedElement()

      if(parent) {
        parent.addJob({
          name: `Job #${parent.jobs.length + 1}`,
          commands: []
        })
      }
    })

    this.on("input", "[data-action=changeJobParallelism]", (e) => {
      let value       = $(e.currentTarget).val()
      let parallelism = parseInt(value, 10)

      let jobIndex = Utils.intAttr(e.currentTarget, "data-job-index")
      let parent   = SelectionRegister.getSelectedElement()
      let job      = parent.jobs[jobIndex]

      this.parent.noRender(() => {
        job.changeParallelism(parallelism)
      })

      $(e.currentTarget).parent().find("output").html(job.parallelism)
    })

    this.on("change", "[data-action=changeParallelismType]", (e) => {
      let selected = $(e.currentTarget).find(":selected")
      let value    = selected.attr("value")
      let parent   = SelectionRegister.getSelectedElement()
      let jobIndex = Utils.intAttr(e.currentTarget, "data-job-index")
      let job      = parent.jobs[jobIndex]

      if(value === PARALLELISM_TYPE_SINGLE_JOB) {
        job.disableMatrix()
        job.disableParallelism()
      }

      if(value === PARALLELISM_TYPE_MULTIPLE_JOBS) {
        job.disableMatrix()
        job.changeParallelism(4)
      }

      if(value === PARALLELISM_TYPE_MATRIX) {
        job.disableParallelism()
        job.changeMatrix([
          { env_var: DEFAULT_MATRIX_ENV_NAMES[0], values: ["value1", "value2"] }
        ])
      }
    })

    this.on("click", "[data-action=addMatrixEnvVar]", (e) => {
      let parent   = SelectionRegister.getSelectedElement()
      let jobIndex = Utils.intAttr(e.currentTarget, "data-job-index")
      let job      = parent.jobs[jobIndex]
      let name     = DEFAULT_MATRIX_ENV_NAMES[job.matrix.length % DEFAULT_MATRIX_ENV_NAMES.length]

      job.addMatrixEnv(name, ["value1", "value2"])
    })

    this.on("click", "[data-action=removeMatrixEnvVar]", (e) => {
      let parent   = SelectionRegister.getSelectedElement()
      let jobIndex = Utils.intAttr(e.currentTarget, "data-job-index")
      let envIndex = Utils.intAttr(e.currentTarget, "data-env-index")
      let job      = parent.jobs[jobIndex]

      job.removeMatrixEnvVar(envIndex)
    })

    this.on("change", "[data-action=changeMatrixEnvVarName]", (e) => {
      let value    = $(e.currentTarget).val().trim()
      let parent   = SelectionRegister.getSelectedElement()
      let jobIndex = Utils.intAttr(e.currentTarget, "data-job-index")
      let envIndex = Utils.intAttr(e.currentTarget, "data-env-index")
      let job      = parent.jobs[jobIndex]

      this.parent.noRender(() => {
        job.changeMatrixEnvVarName(envIndex, value)
      })
    })

    this.on("change", "[data-action=changeMatrixEnvVarValues]", (e) => {
      let value    = $(e.currentTarget).val()
      let parent   = SelectionRegister.getSelectedElement()
      let jobIndex = Utils.intAttr(e.currentTarget, "data-job-index")
      let envIndex = Utils.intAttr(e.currentTarget, "data-env-index")
      let job      = parent.jobs[jobIndex]
      let values   = CSV.parse(value)[0].map(v => v.trim())

      this.parent.noRender(() => {
        job.changeMatrixEnvVarValues(envIndex, values)
      })
    })
  }

  render() {
    let options = {
      title: "Jobs",
      errorCount: 0,
      collapsable: false
    }

    let renderedJobs = this.parent.model.jobs.map((j, index) => {
      return this.renderJob(j, index)
    }).join("\n")

    let linkTitle = ""
    if(this.parent.model.jobs.length === 0) {
      linkTitle = "+ Add first job"
    } else {
      linkTitle = "+ Add job"
    }

    return Section.section(options, `
      <p class="f5 mb2">One command per line.</p>

      ${renderedJobs}

      <div>
        <a data-action=addNewJob href="#" class="db f6">${linkTitle}</a>
      </div>
   `)
  }

  renderJob(job, index) {
    let errors = job.errors.list()
    let errorDiv = ""
    if(errors.length > 0) {
      errorDiv += `<div class="mb2">`
      errorDiv += errors.map(e => `<p class="f6 mb0 red">${e}</p>`).join("\n")
      errorDiv += `</div>`
    }

    let extraConfig = this.renderAdvanced(job, index)

    return `
      <div class="relative flex bg-washed-gray ba b--lighter-gray pa2 br3 mv2">
        <div class="flex-auto">
          ${errorDiv}

          <div class="input-textarea-group flex-auto">
            <input data-action=changeJobName
                   data-job-index=${index}
                   autocomplete="off"
                   type="text" class="form-control form-control-small w-100"
                   placeholder="Name of the Job"
                   value="${ escapeHtml(job.name) }">

            <textarea data-action=changeJobCommands
                      data-job-index=${index}
                      autocomplete="off"
                      class="form-control form-control-small w-100 f6 code"
                      placeholder="Commands…" style="height:48px;overflow-y:hidden;"
                      wrap="off">${ job.commands.join("\n") }</textarea>
          </div>

          <div class="pt1" data-job-index=${index}>
            <details>
              <summary class="f5 gray hover-dark-gray pointer pt1">Configure parallelism or a job matrix</summary>

              <div>
                ${extraConfig}
              </div>
            </details>
          </div>
        </div>

        <div data-action=deleteJob data-job-index=${index} class="flex-shrink-0 f3 fw3 ml2 nt2 nb2 pt2 pl2 pr2 nr2 black-40 hover-black pointer bl b--lighter-gray">
          ×
        </div>
      </div>
    `;
  }

  renderAdvanced(job, index) {
    let content = ""

    if(job.hasParallelismEnabled()) {
      content = `
        <label class="db f7 mb1">Drag slider to select</label>

        <div class="flex items-center">
          <input autocomplete="off" data-action=changeJobParallelism data-job-index=${index} type="range" id="parallelismInput" value="${job.parallelism || 0}" min="2" max="50">

          <output class="dib tc f5 w2 ml2 bg-white pv1 ba b--light-gray br2">${job.parallelismCount()}</output>
        </div>

        <div class="mt2 f7">The SEMAPHORE_JOB_INDEX environment variable is added to every instance.</div>
      `
    } else if(job.hasMatrixEnabled()) {
      let values = ""

      if(job.matrix.length === 0) {
        values = "<span class='f7 gray'>No matrix variable configured.<span>"
      } else {
        job.matrix.forEach((m, envIndex) => {
          let klass = "flex"

          if(envIndex > 0) {
            klass += " mt2"
          }

          values += `
            <div class="${klass}">
              <div class="input-group w-90">
                <input data-action=changeMatrixEnvVarName
                       data-job-index="${index}"
                       data-env-index="${envIndex}"
                       autocomplete="off"
                       type="text"
                       class="w-30 form-control form-control-small code"
                       placeholder="Name"
                       value="${escapeHtml(m.env_var)}">

                <input data-action=changeMatrixEnvVarValues
                       data-job-index="${index}"
                       data-env-index="${envIndex}"
                       autocomplete="off"
                       type="text"
                       class="w-70 form-control form-control-small code"
                       placeholder="Values"
                       value="${escapeHtml(CSV.stringify(m.values))}">
              </div>

              <div data-action=removeMatrixEnvVar data-job-index="${index}" data-env-index="${envIndex}" class="f3 fw3 pl2 pr2 nr2 black-40 hover-black pointer">×</div>
            </div>
          `
        })
      }

      content = `
        <label class="f7">Matrix Configuration</label>
        <div class="pt1">
          ${values}
        </div>

        <a href="#" class="f7 gray db pt2" data-action=addMatrixEnvVar data-job-index=${index}>+ Add variable</a>
      `
    }

    let options = [
      {value: PARALLELISM_TYPE_SINGLE_JOB, selected: !(job.hasParallelismEnabled() || job.hasMatrixEnabled()), text: "Single instance"},
      {value: PARALLELISM_TYPE_MULTIPLE_JOBS, selected: job.hasParallelismEnabled(), text: "Multiple instances"},
      {value: PARALLELISM_TYPE_MATRIX, selected: job.hasMatrixEnabled(), text: "Multiple instances based on a matrix"}
    ]

    return `
      <div class="mt2 ph2 pt2 nh2 bt b--lighter-gray">
        <div class="flex justify-between">
          <label for="parallelism-type-${index}" class="pt1 b f5">How many parallel instances to run?</label>
        </div>

        <p class="f5 mb0">You can run multiple instances of this job. Each job runs with a dedicated agent.</p>

        <div class="mv2">
          <select name="parallelism-type-${index}" class="form-control form-control-small w-50" data-action=changeParallelismType data-job-index="${index}">
            ${options.map((o) => `<option value="${escapeHtml(o.value)}" ${o.selected ? "selected" : ""}>${o.text}</option>`)}
          </select>
        </div>

        ${content}
      </div>
    `
  }

  on(event, selector, callback) {
    this.parent.on(event, selector, callback)
  }

  parseCommands(rawCommands) {
    return rawCommands.split("\n").filter((line) => {
      return !/^\s*$/.test(line)
    })
  }
}
