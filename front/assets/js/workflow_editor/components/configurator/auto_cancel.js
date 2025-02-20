import $ from "jquery";
import _ from "lodash";

import { Section } from "../../templates/configurator/section"

const STRATEGIES = [
  {
    strategy: "do-nothing",
    config: {running: "", queued: ""},
    description: "Do nothing"
  },
  {
    strategy: "cancel-all",
    config: {running: "true", queued: ""},
    description: "Cancel all pipelines, both running and queued"
  },
  {
    strategy: "cancel-queued",
    config: {running: "", queued: "true"},
    description: "Cancel only queued pipelines"
  },
  {
    strategy: "cancel-master",
    config: { running: "branch != 'master'", queued: "branch = 'master'" },
    description: "On the master branch cancel only queued pipelines, on others cancel both running and queued"
  },
  {
    strategy: "custom",
    description: "Run a custom auto-cancel strategy"
  }
]

export class AutoCancelConfig {
  constructor(parent) {
    this.parent = parent

    this.handleEvents()
  }

  activeStrategy() {
    let running = this.parent.model.autoCancel.getRunningStrategy()
    let queued = this.parent.model.autoCancel.getQueuedStrategy()

    let strategy = STRATEGIES
      .filter(s => _.has(s, "config"))
      .find(s => s.config.running === running && s.config.queued === queued)

    if(strategy) {
      return strategy
    } else {
      return STRATEGIES.find(s => s.strategy === "custom")
    }
  }

  handleEvents() {
    this.on("change", "[data-action=selectAutoCancelType]", (e) => {
      let selected = $(e.currentTarget).find(":selected")
      let value    = selected.attr("value")

      let strategy = STRATEGIES.find(s => s.strategy === value)
      let model = this.parent.model

      if(strategy.strategy === "custom") {
        model.autoCancel.set("branch != 'dev'", "branch = 'dev'")
      } else {
        model.autoCancel.set(strategy.config.running, strategy.config.queued)
      }
    })

    this.on("input", "[data-action=changeAutoCancelRunning]", _.debounce((e) => {
      this.noRender(() => {
        let value = $(e.currentTarget).val()

        this.parent.model.autoCancel.setRunningStrategy(value)
      })
    }, 500))

    this.on("input", "[data-action=changeAutoCancelQueued]", _.debounce((e) => {
      this.noRender(() => {
        let value = $(e.currentTarget).val()

        this.parent.model.autoCancel.setQueuedStrategy(value)
      })
    }, 500))
  }

  render() {
    let sectionOptions = {
      title: "Auto-Cancel",
      status: "",
      collapsable: true
    }

    let content = `
      <p class="f5 mb2">When you push to a branch, Semaphore can automatically cancel the pipelines still running on the same branch.</p>

      <label for=auto-cancel-type class="db f5 gray mb1">What to do with previous pipelines on a branch or pull-request?</label>

      <select name="auto-cancel-type" data-action=selectAutoCancelType class="form-control form-control-small w-100">
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
    let ac = this.parent.model.autoCancel
    let running = ac.getRunningStrategy()
    let queued = ac.getQueuedStrategy()

    return `
      <div class="mt2 pa2 bg-washed-gray ba b--lighter-gray br3">
        <label for="auto-cancel-running-condition" class="f6 db fw5 mb1">Cancel both running and queued pipelines when:</label>
        <input type="text" id="auto-cancel-running-condition" data-action="changeAutoCancelRunning" class="form-control form-control-small w-100 " placeholder="ex. ${escapeHtml("branch != 'dev'")}" value="${escapeHtml(running)}">

        <label for="auto-cancel-queued-condition" class="f6 db fw5 mb1 mt2">Cancel only queued pipelines when:</label>
        <input type="text" id="auto-cancel-queued-condition" data-action="changeAutoCancelQueued" class="form-control form-control-small w-100 " placeholder="ex. ${escapeHtml("branch != 'dev'")}" value="${escapeHtml(queued)}">

        <p class="f6 mt2 gray mb0">Use <a class="gray" href="${docs}" target="_blank" rel="noopener">Conditional DSL</a> for specifying auto-cancel rules.</p>
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
