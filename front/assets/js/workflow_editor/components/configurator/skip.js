import $ from "jquery"
import _ from "lodash"

import { Section } from "../../templates/configurator/section"

const TYPE_ALWAYS = "always"
const TYPE_SKIP = "skip"
const TYPE_RUN = "run"

export class SkipConfig {
  constructor(parent) {
    this.parent = parent

    this.handleEvents()
  }

  handleEvents() {
    this.on("change", "[data-action=selectConditionType]", (e) => {
      let selected = $(e.currentTarget).find(":selected")
      let value    = selected.attr("value")

      switch(value) {
      case TYPE_ALWAYS:
        return this.setTypeToAlways()

      case TYPE_SKIP:
        return this.setTypeToSkip()

      case TYPE_RUN:
        return this.setTypeToRun()
      }
    })

    this.on("input", "[data-action=changeSkipCondition]", _.debounce((e) => {
      this.noRender(() => {
        let condition = $(e.currentTarget).val()

        this.parent.model.setSkipConditions(condition)
      })
    }, 500))

    this.on("input", "[data-action=changeRunCondition]", _.debounce((e) => {
      this.noRender(() => {
        let condition = $(e.currentTarget).val()

        this.parent.model.setRunConditions(condition)
      })
    }, 500))

    this.on("click", "[data-action=useExample]", (e) => {
      let example = $(e.currentTarget).parent().find("input").val()

      if(this.parent.model.hasSkipConditions()) {
        this.parent.model.setSkipConditions(example)
        return
      }

      if(this.parent.model.hasRunConditions()) {
        this.parent.model.setRunConditions(example)
        return
      }
    })
  }

  setTypeToAlways() {
    this.parent.model.clearConditionsForRunning()
  }

  setTypeToRun() {
    if(this.parent.model.hasSkipConditions()) {
      this.parent.model.setRunConditions(this.parent.model.skipCondition)
    } else {
      this.parent.model.setRunConditions("branch = 'master'")
    }
  }

  setTypeToSkip() {
    if(this.parent.model.hasRunConditions()) {
      this.parent.model.setSkipConditions(this.parent.model.runCondition)
    } else {
      this.parent.model.setSkipConditions("branch = 'master'")
    }
  }

  on(event, selector, callback) {
    this.parent.on(event, selector, callback)
  }

  noRender(cb) {
    this.parent.noRender(cb)
  }

  render() {
    let block = this.parent.model

    let options = {
      title: "Skip/Run conditions",
      status: (block.hasConditionForRunning() ? "has condition" : null),
      collapsable: true
    }

    return Section.section(options, this.renderPanel(block))
  }

  renderPanel(block) {
    return `
      <p class="f6 mb2">
        Skip the block under certain conditions.
      </p>

      <select name="condition-type" data-action=selectConditionType class="form-control form-control-small w-100">
        ${this.renderOption(TYPE_ALWAYS, !block.hasConditionForRunning(), "Always run this block (no conditions)")}
        ${this.renderOption(TYPE_RUN, block.hasRunConditions(), "Run this block when conditions are met")}
        ${this.renderOption(TYPE_SKIP, block.hasSkipConditions(), "Skip this block when conditions are met")}
      </select>

      ${this.renderWhen(block)}
    `
  }

  renderOption(value, selected, description) {
    let selectedTag = selected ? "selected" : ""

    return `<option value="${value}" ${selectedTag}>${description}</option>`
  }

  renderWhen(block) {
    if(!block.hasConditionForRunning()) return "";

    return `
      <div class="pa2 mt2 bg-washed-gray ba b--lighter-gray br3">
        ${this.renderWhenInput(block)}
        ${this.renderExamples()}
      </div>
    `
  }

  renderWhenInput(block) {
    let label, condition, action;

    if(block.hasRunConditions()) {
      label = "Run when?"
      action = "changeRunCondition"
      condition = block.runCondition
    } else {
      label = "Skip when?"
      action = "changeSkipCondition"
      condition = block.skipCondition
    }

    return `
      <label for="skip-condition" class="f6 db fw5 mb1">${label}</label>

      <input
        id="skip-condition"
        type="text"
        data-action="${action}"
        class="form-control form-control-small w-100"
        placeholder="Enter Condition..."
        value="${escapeHtml(condition)}">
    `
  }

  renderExamples() {
    return `
      <div class="db f6 fw5 mt3 nb1">Common examples</div>

      ${this.renderExample("On master branch or any tag", "branch = 'master' or tag =~ '.*'")}
      ${this.renderExample("When a file changes in the lib directory", "change_in('/lib')")}

      <p class="f6 mt3 mb0">
        See <a href="https://docs.semaphoreci.com/reference/conditions-reference/" target="_blank">Conditions Reference</a> and <a href="https://docs.semaphoreci.com/essentials/building-monorepo-projects/" target="_blank">Monorepo Guide</a> for more examples.
      </p>
    `
  }

  renderExample(description, condition) {
    return `
      <div class="mt2">
        <label class="db f6 gray mb1">${description}</label>

        <div class="input-button-group">
          <input type="text" class="form-control form-control-small w-100" value="${escapeHtml(condition)}" readonly="">

          <button data-action="useExample" class="btn btn-secondary btn-small">Use</button>
        </div>
      </div>
    `
  }
}
