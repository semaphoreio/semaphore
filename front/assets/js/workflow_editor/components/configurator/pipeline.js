import _ from "lodash";
import $ from "jquery";

import { Utils } from "./utils"
import { AgentConfigurator } from "./agent"
import { FastFailConfig } from "./fast_fail"
import { AutoCancelConfig } from "./auto_cancel"

import { PrologueConfig } from "./prologue"
import { EpilogueConfig } from "./epilogue"

import { SelectionRegister }     from "../../selection_register"
import { PipelineConfigTempate } from "../../templates/configurator/pipeline"

export class PipelineConfigurator {

  //
  // Accepts three arguments:
  //   parent            - The parent view element, in this case the ConfiguratorView
  //   model             - The pipeline model we are configuring in this view
  //   outputDivSelector - The selector where we are rendering the elements
  //
  constructor(parent, model, outputDivSelector) {
    this.parent = parent
    this.outputDivSelector = outputDivSelector
    this.model = model

    this.registerNameChangeHandler()
    this.registerFilePathChangeHandler()
    this.registerExecutionTimeLimitHandler()
    this.registerDeletePipelineHandler()

    this.agentConfig = new AgentConfigurator(this)

    this.fastFailConfig = new FastFailConfig(this)
    this.autoCancelConfig = new AutoCancelConfig(this)
    this.prologueConfig = new PrologueConfig(this)
    this.epilogueConfig = new EpilogueConfig(this)

    this.renderingDisabled = false
  }

  registerNameChangeHandler() {
    let handler = (e) => {
      this.noRender(() => {
        let name = $(e.currentTarget).val()
        let pipeline = SelectionRegister.getSelectedElement()

        pipeline.changeName(name)
      })
    }

    $(this.outputDivSelector).on("input", "[data-action=changePipelineName]", (e) => handler(e))
  }

  registerFilePathChangeHandler() {
    let handler = (e) => {
      this.noRender(() => {
        let path = $(e.currentTarget).val()
        let pipeline = SelectionRegister.getSelectedElement()

        pipeline.changeFilePath(path)
      })
    }

    $(this.outputDivSelector).on("input", "[data-action=changeFilePath]", (e) => handler(e))
  }

  registerExecutionTimeLimitHandler() {
    let handler = _.debounce((pipeline, unit, val) => {
      this.noRender(() => {
        pipeline.executionTimeLimit.change(unit, val)
      })
    }, 500)

    this.on("input", "[data-action=changePipelineExecutionTimeLimit]", (e) => {
      this.noRender(() => {
        let parent = $(e.currentTarget).closest("details")

        let val = parseInt(parent.find("input").val(), 10)
        let unit = _.lowerCase(parent.find("select option:selected").text())

        let pipeline = SelectionRegister.getSelectedElement()

        handler(pipeline, unit, val)
      })
    })
  }

  registerDeletePipelineHandler() {
    this.on("click", "[data-action=deletePipeline]", () => {
      let pipeline = SelectionRegister.getSelectedElement()

      let isConfirmed = confirm(`This will also delete everything that comes after the pipeline! Are you sure?`)

      if(isConfirmed) {
        pipeline.workflow.deletePipeline(pipeline)
      }
    })
  }

  on(event, selector, callback) {
    this.parent.on(event, `[data-type=pipeline] ${selector}`, callback)
  }

  render() {
    if(this.renderingDisabled) return;

    Utils.preserveSelectedElement(() => {
      Utils.preserveDropdownState(this.outputDivSelector, () => {
        let elements = [
          PipelineConfigTempate.name(this.model),
          PipelineConfigTempate.agent(this.model),
          this.prologueConfig.render(),
          this.epilogueConfig.render(),
          PipelineConfigTempate.executionTimeLimit(this.model),
          this.fastFailConfig.render(),
          this.autoCancelConfig.render(),
          PipelineConfigTempate.path(this.model),
          PipelineConfigTempate.deletePipeline(this.model)
        ]

        $(this.outputDivSelector).html(elements.join("\n"))
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
