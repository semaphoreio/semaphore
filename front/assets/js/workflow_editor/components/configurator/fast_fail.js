import $ from "jquery";
import _ from "lodash";

import { Section } from "../../templates/configurator/section"

const STRATEGIES = [
  {
    strategy: "do-nothing",
    config: {stop: "", cancel: ""},
    description: "Do nothing"
  },
  {
    strategy: "stop-jobs",
    config: {stop: "true", cancel: ""},
    description: "Stop all remaining jobs"
  },
  {
    strategy: "cancel-jobs",
    config: {stop: "", cancel: "true"},
    description: "Cancel all pending jobs, wait for started ones to finish"
  },
  {
    strategy: "stop-jobs-on-non-master",
    config: { stop: "branch != 'master'", cancel: "" },
    description: "Stop remaining jobs, unless the job is running on the master branch"
  },
  {
    strategy: "custom",
    description: "Run a custom fail-fast strategy"
  }
]

export class FastFailConfig {
  constructor(parent) {
    this.parent = parent

    this.handleEvents()
  }

  activeStrategy() {
    let stop = this.parent.model.failFast.getStopStrategy()
    let cancel = this.parent.model.failFast.getCancelStrategy()

    let strategy = STRATEGIES
      .filter(s => _.has(s, "config"))
      .find(s => s.config.stop === stop && s.config.cancel === cancel)

    if(strategy) {
      return strategy
    } else {
      return STRATEGIES.find(s => s.strategy === "custom")
    }
  }

  handleEvents() {
    this.on("change", "[data-action=selectFailFastType]", (e) => {
      let selected = $(e.currentTarget).find(":selected")
      let value    = selected.attr("value")

      let strategy = STRATEGIES.find(s => s.strategy === value)
      let model = this.parent.model

      if(strategy.strategy === "custom") {
        model.failFast.set("branch != 'dev'", "branch = 'dev'")
      } else {
        model.failFast.set(strategy.config.stop, strategy.config.cancel)
      }
    })

    this.on("input", "[data-action=changeFailFastStop]", _.debounce((e) => {
      this.noRender(() => {
        let value = $(e.currentTarget).val()

        this.parent.model.failFast.setStopStrategy(value)
      })
    }, 500))

    this.on("input", "[data-action=changeFailFastCancel]", _.debounce((e) => {
      this.noRender(() => {
        let value = $(e.currentTarget).val()

        this.parent.model.failFast.setCancelStrategy(value)
      })
    }, 500))
  }

  render() {
    let sectionOptions = {
      title: "Fail-Fast",
      status: "",
      collapsable: true
    }

    let content = `
      <p class="f5 mb2">In case a job fails, Semaphore can automatically stop the remaining jobs.</p>

      <label for=fail-fast-type class="db f5 gray mb1">What to do when a job fails?</label>

      <select name="fail-fast-type" data-action=selectFailFastType class="form-control form-control-small w-100">
        ${this.renderStrategyOptions()}
      </select>

      ${this.activeStrategy().strategy === "custom" ? this.renderAdvanced() : ""}
    `

    return Section.section(sectionOptions, content)
  }

  renderStrategyOptions() {
    return STRATEGIES.map((s) => {
      return `<option value="${s.strategy}" ${this.activeStrategy().strategy === s.strategy ? "selected" : ""}>
        ${s.description}
      </option>`
    }).join("\n")
  }

  renderAdvanced() {
    let docs = "https://docs.semaphoreci.com/reference/conditions-reference"
    let ff = this.parent.model.failFast
    let stop = ff.getStopStrategy()
    let cancel = ff.getCancelStrategy()

    return `
      <div class="mt2 pa2 bg-washed-gray ba b--lighter-gray br3">
        <label for="force-fail-stop-condition" class="f6 db fw5 mb1">Stop all jobs when:</label>
        <input type="text" id="force-fail-stop-condition" data-action="changeFailFastStop" class="form-control form-control-small w-100 " placeholder="ex. ${escapeHtml("branch != 'dev'")}" value="${escapeHtml(stop)}">

        <label for="force-fail-cancel-condition" class="f6 db fw5 mb1 mt2">Stop only pending jobs when:</label>
        <input type="text" id="force-fail-cancel-condition" data-action="changeFailFastCancel" class="form-control form-control-small w-100 " placeholder="ex. ${escapeHtml("branch != 'dev'")}" value="${escapeHtml(cancel)}">

        <p class="f6 mt2 gray mb0">Use <a class="gray" href="${docs}" target="_blank" rel="noopener">Conditional DSL</a> for specifying fail-fast rules.</p>
      </div>
    `
  }

  on(event, selector, callback) {
    this.parent.on(event, selector, callback)
  }

  noRender(cb) {
    this.parent.noRender(cb)
  }
}
