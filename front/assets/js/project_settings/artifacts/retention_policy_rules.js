import _ from "lodash"
import $ from "jquery"

const ONE_DAY = 24 * 3600
const ONE_WEEK = 7 * 24 * 3600
const ONE_MONTH = 30 * 24 * 3600
const ONE_YEAR = 365 * 24 * 3600
const MAX_RULES = 10

export class RetentionPolicyRules {
  constructor(artifactType, container, policies, readOnly) {
    this.artifactType = artifactType
    this.container = container
    this.policies = policies
    this.readOnly = readOnly

    this.render()
    this.injectInitialPolicies()

    this.handleAddRetentionPolicyClick()
    this.handleRemoveRetentionPolicyClick()
  }

  injectInitialPolicies() {
    let zeroStateContainer = this.container.find("[data-name=zero-state]")
    let inputListContainer = this.container.find("[data-name=policy-list")

    this.zeroState = new ZeroState(zeroStateContainer, this.artifactType)
    this.inputList = new InputList(
      inputListContainer,
      this.artifactType,
      this.readOnly
    )

    this.policies.forEach((policy) => {
      this.inputList.add(policy.selector, policy.age)
    })

    this.update()
  }

  handleAddRetentionPolicyClick() {
    this.handleAction("add-retention-policy", () => {
      this.inputList.addEmpty()
    })
  }

  handleRemoveRetentionPolicyClick() {
    this.handleAction("remove-retention-policy", (e) => {
      $(e.currentTarget).closest("[data-name=input-form]").remove()
    })
  }

  handleAction(action, f) {
    $(this.container).on("click", `[data-action=${action}]`, (e) => {
      e.preventDefault()
      f(e)
      this.update()
    })
  }

  update() {
    this.updateZeroStateVisibility()
    this.updateMaxRulesMessageVisibility()
  }

  updateZeroStateVisibility() {
    if (this.inputList.isEmpty()) {
      this.zeroState.show()
      this.inputList.hide()
    } else {
      this.zeroState.hide()
      this.inputList.show()
    }
  }

  updateMaxRulesMessageVisibility() {
    if (this.inputList.count() >= MAX_RULES) {
      this.hideAddRetentionLink()
      this.showRuleLimit()
    } else {
      this.showAddRetentionLink()
      this.hideRuleLimit()
    }
  }

  render() {
    this.container.html(`
      <div class="${this.containerBorder()} pa3">
        <label class="b db">${_.capitalize(this.artifactType)} Artifacts</label>
        <div class="gray f6 mb2">Rules are applied in order. The first match decides the retention age.</div>

        <div data-name="zero-state" class="f6 bg-white pa2 br3 ba b--black-075 dn"></div>
        <div data-name="policy-list" class="dn"></div>

        ${this.renderAddRetentionPolicy()}
        ${this.renderRuleLimit()}
      </div>
    `)
  }

  containerBorder() {
    if (this.artifactType !== "job") {
      return "bb b--black-075"
    } else {
      return ""
    }
  }

  renderAddRetentionPolicy() {
    if (this.readOnly) {
      return ""
    } else {
      return `<a href="#" data-action=add-retention-policy class="f7 gray db pt2">+ Add retention policy</a>`
    }
  }

  showAddRetentionLink() {
    this.findAddRetentionPolicyLink().removeClass("dn").addClass("db")
  }

  hideAddRetentionLink() {
    this.findAddRetentionPolicyLink().addClass("dn").removeClass("db")
  }

  findAddRetentionPolicyLink() {
    return $(this.container).find("[data-action=add-retention-policy]")
  }

  renderRuleLimit() {
    if (this.readOnly) {
      return ""
    } else {
      return `<span data-name=rule-limit class="f7 gray dn pt2">You can have at most ${MAX_RULES} rules.</span>`
    }
  }

  showRuleLimit() {
    this.findRuleLimit().removeClass("dn").addClass("db")
  }

  hideRuleLimit() {
    this.findRuleLimit().addClass("dn").removeClass("db")
  }

  findRuleLimit() {
    return $(this.container).find("[data-name=rule-limit]")
  }
}

class ZeroState {
  constructor(container, artifactType) {
    this.container = container
    this.artifactType = artifactType

    this.render()
  }

  render() {
    this.container.html(
      `No policy set. ${_.capitalize(
        this.artifactType
      )} level artifacts are never deleted.`
    )
  }

  show() {
    return this.container.removeClass("dn")
  }

  hide() {
    return this.container.addClass("dn")
  }
}

class InputList {
  constructor(container, artifactType, readOnly) {
    this.container = container
    this.readOnly = readOnly
    this.artifactType = artifactType

    this.render()
  }

  render() {
    this.container.html(``)
  }

  show() {
    return this.container.removeClass("dn")
  }

  hide() {
    return this.container.addClass("dn")
  }

  isEmpty() {
    return this.container.find("[data-name=input-form]").length === 0
  }

  count() {
    return this.container.find("[data-name=input-form]").length
  }

  addEmpty() {
    this.add("", ONE_WEEK)
  }

  add(selector, age) {
    this.container.append(`
      <div data-name="input-form" class="pt1">
        <div class="flex">
          <div class="input-group w-90">
            ${this.renderInputField(selector)}
            ${this.renderAgeSelector(age)}
          </div>

          ${this.renderRemoveButton()}
        </div>
      </div>
    `)
  }

  renderRemoveButton() {
    if (this.readOnly) {
      return ""
    } else {
      return `<div data-action=remove-retention-policy class="f3 fw3 pl2 pr2 nr2 black-40 hover-black pointer">×</div>`
    }
  }

  renderInputField(selector) {
    return `
      <input autocomplete="off"
             ${this.formName("selector")}
             type="text"
             ${this.readOnly ? "disabled" : ""}
             class="w-70 form-control form-control-small code"
             placeholder="/example/path/**/*"
             value="${selector}">
    `
  }

  renderAgeSelector(age) {
    let disabledAttr = this.readOnly ? "disabled" : ""

    return `
      <select ${disabledAttr} class="form-control form-control-small w-30" ${this.formName(
      "age"
    )}>
        ${this.renderAgeOptions(age)}
      </select>
    `
  }
  renderAgeOptions(selectedValue) {
    let matchFound = false
    let options = [
      { value: 1 * ONE_DAY, optionName: "1 day" },
      { value: 2 * ONE_DAY, optionName: "2 days" },
      { value: 3 * ONE_DAY, optionName: "3 days" },
      { value: 4 * ONE_DAY, optionName: "4 days" },
      { value: 5 * ONE_DAY, optionName: "5 days" },
      { value: 6 * ONE_DAY, optionName: "6 days" },

      { value: 1 * ONE_WEEK, optionName: "1 week" },
      { value: 2 * ONE_WEEK, optionName: "2 weeks" },
      { value: 3 * ONE_WEEK, optionName: "3 weeks" },

      { value: 1 * ONE_MONTH, optionName: "1 month" },
      { value: 2 * ONE_MONTH, optionName: "2 months" },
      { value: 3 * ONE_MONTH, optionName: "3 months" },
      { value: 6 * ONE_MONTH, optionName: "6 months" },

      { value: ONE_YEAR, optionName: "1 year" },
      { value: 2 * ONE_YEAR, optionName: "2 years" },
      { value: 3 * ONE_YEAR, optionName: "3 years" },
      { value: 5 * ONE_YEAR, optionName: "5 years" },
    ]

    options = options.map((option) => {
      let selected = option.value === selectedValue ? "selected" : ""
      if (selected == "selected") {
        matchFound = true
      }
      return {
        value: option.value,
        selected: selected,
        optionName: option.optionName,
      }
    })

    if (!matchFound) {
      // custom value, need to try divide by ONE_YEAR, ONE_MONTH, ONE_WEEK, ONE_DAY and see if it is an integer
      if (selectedValue % ONE_YEAR == 0) {
        options.push({
          value: selectedValue,
          selected: "selected",
          optionName: `${selectedValue / ONE_YEAR} years`,
        })
      } else if (selectedValue % ONE_MONTH == 0) {
        options.push({
          value: selectedValue,
          selected: "selected",
          optionName: `${selectedValue / ONE_MONTH} months`,
        })
      } else if (selectedValue % ONE_WEEK == 0) {
        options.push({
          value: selectedValue,
          selected: "selected",
          optionName: `${selectedValue / ONE_WEEK} weeks`,
        })
      } else {
        options.push({
          value: selectedValue,
          selected: "selected",
          optionName: `${selectedValue / ONE_DAY} days`,
        })
      }
    }

    return options
      .map((option) => {
        return this.renderAgeOption(
          option.value,
          option.optionName,
          option.selected
        )
      })
      .join("\n")
  }

  renderAgeOption(value, text, selected) {
    return `<option value="${value}" 
      ${selected}>${text}</option>`
  }

  formName(name) {
    return `name="artifact_settings[${this.artifactType}][${name}][]"`
  }
}
