import $ from "jquery"
import _ from "lodash"

import { Utils } from "./utils"

import { AgentConfigurator } from "./agent"
import { PrologueConfig } from "./prologue"
import { EpilogueConfig } from "./epilogue"
import { JobsConfig } from "./jobs"
import { SkipConfig } from "./skip"

import { SelectionRegister } from "../../selection_register"
import { BlockConfigTemplate } from "../../templates/configurator/block"

export class BlockConfigurator {

  //
  // Accepts three arguments:
  //   parent            - The parent view element, in this case the ConfiguratorView
  //   model             - The block model we are configuring in this view
  //   outputDivSelector - The selector where we are rendering the elements
  //
  constructor(parent, model, outputDivSelector) {
    this.outputDivSelector = outputDivSelector
    this.model = model
    this.parent = parent

    this.registerNameChangeHandler()
    this.registerSkipConditionChangeHandler()

    this.registerSecretToggleHandler()
    this.registerDependencyToggleHandler()
    this.registerEnvVarHandler()

    this.registerDeleteBlockHandler()

    this.agentView = new AgentConfigurator(this)
    this.registerAgentOverrideEnabled()

    this.prologueConfig = new PrologueConfig(this)
    this.epilogueConfig= new EpilogueConfig(this)
    this.jobsConfig = new JobsConfig(this)
    this.skipConfig = new SkipConfig(this)

    this.renderingDisabled = false
  }

  registerNameChangeHandler() {
    let handler = _.throttle((e) => {
      this.noRender(() => {
        let name = $(e.currentTarget).val()
        let block = SelectionRegister.getSelectedElement()

        block.changeName(name)
      })
    }, 50)

    this.on("input", "[data-action=changeBlockName]", (e) => handler(e))
  }

  registerSkipConditionChangeHandler() {
    let handler = _.debounce((block, condition) => {
      this.noRender(() => {
        block.changeSkipCondition(condition)
      })
    }, 500)

    this.on("input", "[data-action=changeBlockSkipCondition]", (e) => {
      let condition = $(e.currentTarget).val()
      let block = SelectionRegister.getSelectedElement()

      if(block) {
        handler(block, condition)
      }
    })
  }

  registerSecretToggleHandler() {
    this.on("click", "[data-action=toggleBlockSecret]", (e) => {
      let secretName = $(e.currentTarget).attr("data-secret-name")
      let checked = $(e.currentTarget).is(":checked")
      let block = SelectionRegister.getSelectedElement()

      if(block) {
        if(checked) {
          block.secrets.add(secretName)
        } else {
          block.secrets.remove(secretName)
        }
      }

      this.render()
    })
  }

  registerDependencyToggleHandler() {
    this.on("click", "[data-action=toggleBlockDependency]", (e) => {
      let dependencyName = $(e.currentTarget).attr("data-dependency-name")
      let checked = $(e.currentTarget).is(":checked")
      let block = SelectionRegister.getSelectedElement()

      if(block) {
        if(checked) {
          block.dependencies.add(dependencyName)
        } else {
          block.dependencies.remove(dependencyName)
        }
      }
    })
  }

  registerDeleteBlockHandler() {
    this.on("click", "[data-action=deleteBlock]", () => {
      let block = SelectionRegister.getSelectedElement()

      if(block) {
        let isConfirmed = confirm(`Deleting ${block.name}. Are You sure?`)

        if(isConfirmed) {
          block.remove()
        }
      }
    })
  }

  registerEnvVarHandler() {
    this.on("click", "[data-action=addBlockEnvVar]", () => {
      let block = SelectionRegister.getSelectedElement()

      block.envVars.addNew()

      this.render()
    })

    let changeHandler = _.debounce((block, index, name, value) => {
      this.noRender(() => {
        block.envVars.change(index, name, value)
      })
    })

    this.on("input", "[data-action=changeBlockEnvVar]", (e) => {
      let block = SelectionRegister.getSelectedElement()
      let index = Utils.intAttr(e.currentTarget, "data-env-var-index")

      let name = $(e.currentTarget).parent().find("input").first().val()
      let value = $(e.currentTarget).parent().find("input").last().val()

      changeHandler(block, index, name, value)
    })

    this.on("click", "[data-action=removeBlockEnvVar]", (e) => {
      let block = SelectionRegister.getSelectedElement()
      let index = Utils.intAttr(e.currentTarget, "data-env-var-index")

      block.envVars.remove(index)

      this.render()
    })
  }

  registerAgentOverrideEnabled() {
    this.on("click", "[data-action=toggleAgentOverrideEnabled]", (e) => {
      let checked = $(e.currentTarget).is(":checked")
      let block = SelectionRegister.getSelectedElement()

      block.changeOverrideGlobalAgent(checked)

      this.render()
    })
  }

  parseCommands(rawCommands) {
    return rawCommands.split("\n").filter((line) => {
      return !/^\s*$/.test(line)
    })
  }

  on(event, selector, callback) {
    this.parent.on(event, `[data-type=block] ${selector}`, callback)
  }

  render() {
    if(this.renderingDisabled) return;

    Utils.preserveScrollPositions(this.outputDivSelector, () => {
      // Utils.preserveSelectedElement(() => {
        Utils.preserveDropdownState(this.outputDivSelector, () => {
          let html = `
            ${ BlockConfigTemplate.name(this.model) }
            ${ BlockConfigTemplate.deps(this.model) }
            ${ this.jobsConfig.render() }
            ${ this.prologueConfig.render() }
            ${ this.epilogueConfig.render() }
            ${ BlockConfigTemplate.envVars(this.model) }
            ${ BlockConfigTemplate.secrets(this.model) }
            ${ this.skipConfig.render() }
            ${ BlockConfigTemplate.agent(this.model) }
            ${ BlockConfigTemplate.deleteBlock() }
          `

          $(this.outputDivSelector).html(html)
        // })
      })

      $(this.outputDivSelector).find('textarea').each((_index, el) => {
        this.parent.resizeTextAreaToFitText(el)
      })
    })
  }

  noRender(cb) {
    try {
      this.renderingDisabled = true
      cb()
    } finally {
      this.renderingDisabled = false
    }
  }
}
