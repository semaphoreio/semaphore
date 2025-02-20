import $ from "jquery";

import { SelectionRegister } from "../selection_register"

import { BlockConfigurator } from "./configurator/block"
import { PipelineConfigurator } from "./configurator/pipeline"
import { PromotionConfigurator } from "./configurator/promotion"
import { AfterPipelineConfigurator } from "./configurator/after_pipeline"

import nothingSelectedTemplate from "../templates/configurator/no_selection"

export class Configurator {
  constructor(parent, model, outputDivSelector) {
    this.parent = parent
    this.outputDivSelector = outputDivSelector
    this.outputDivContentSelector = "#workflow-editor-config-panel-content"
    this.model = model
    this.currentDisplayedElementUid = null

    this.blockConfigurator = new BlockConfigurator(
      this,
      model,
      this.outputDivContentSelector)

    this.pipelineConfigurator = new PipelineConfigurator(
      this,
      model,
      this.outputDivContentSelector)

    this.promotionConfigurator = new PromotionConfigurator(
      this,
      this.outputDivContentSelector)

    this.afterPipelineConfigurator = new AfterPipelineConfigurator(
      this,
      this.outputDivContentSelector)

    this.autoExpandTextAreas()
    this.setInitialWidth()
  }

  setInitialWidth() {
    $(this.outputDivSelector).width("40%");
  }

  hide() {
    if(!this.isVisible) return;

    $(this.outputDivSelector).hide()
    this.isVisible = false

    this.update()
  }

  show() {
    if(this.isVisible) return;

    $(this.outputDivSelector).show()
    this.isVisible = true

    this.update()
  }

  resizeTextAreaToFitText(element) {
    element.style.height = 'inherit';

    // Get the computed styles for the element
    let computed = window.getComputedStyle(element)

    // Calculate the height
    var height = parseInt(computed.getPropertyValue('border-top-width'), 10)
                 + parseInt(computed.getPropertyValue('padding-top'), 10)
                 + element.scrollHeight
                 + parseInt(computed.getPropertyValue('padding-bottom'), 10)
                 + parseInt(computed.getPropertyValue('border-bottom-width'), 10)

    element.style.height = (height + 2) + 'px'
  }

  autoExpandTextAreas() {
    $(this.outputDivSelector).on("paste input", "textarea", (event) => {
      this.resizeTextAreaToFitText(event.currentTarget)
    })

    //
    // Size needs to be re-adjusted every time the details are opened.
    // Hidden elements don't have a scrollHeight.
    //
    $(this.outputDivSelector).on("click", "details", () => {
      $(this.outputDivSelector).find("textarea").each((index, el) => {
        //
        // When the expansion happens, the elements still doesn't have a
        // scroll height. A timeout of <N>ms makes sure that the DOM element is
        // populated with data.
        //
        setTimeout(() => {
          this.resizeTextAreaToFitText(el)
        }, 10)
      })
    })
  }

  on(event, selector, callback) {
    this.parent.on(event, `${this.outputDivSelector} ${selector}`, callback)
  }

  update() {
    if(!this.isVisible) return;

    let uid = SelectionRegister.getCurrentSelectionUid()

    if (uid == null) {
      let h = nothingSelectedTemplate()

      $(this.outputDivContentSelector).attr("data-type", "none")
      $(this.outputDivContentSelector).html(h)
      return
    }

    let model = SelectionRegister.lookup(uid)

    switch(model.modelName) {
    case "block":
      $(this.outputDivContentSelector).attr("data-type", "block")
      this.blockConfigurator.model = model
      this.blockConfigurator.render()
      break

    case "pipeline":
      $(this.outputDivContentSelector).attr("data-type", "pipeline")
      this.pipelineConfigurator.model = model
      this.pipelineConfigurator.render()
      break

    case "promotion":
      $(this.outputDivContentSelector).attr("data-type", "promotion")
      this.promotionConfigurator.render(model)
      break

    case "after_pipeline":
      $(this.outputDivContentSelector).attr("data-type", "afterPipeline")
      this.afterPipelineConfigurator.render(model)
      break
    }
  }

}
