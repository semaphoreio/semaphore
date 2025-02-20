import $ from "jquery";
import _ from "lodash";

import { Utils }                  from "./utils"
import { SelectionRegister }      from "../../selection_register"
import { PromotionConfigTemplate } from "../../templates/configurator/promotion"
import { PromotionParameters }    from "./promotion_parameters"
import { Features } from "../../../features";

export class PromotionConfigurator {

  //
  // Accepts three arguments:
  //   parent            - The parent view element, in this case the ConfiguratorView
  //   outputDivSelector - The selector where we are rendering the elements
  //
  constructor(parent, outputDivSelector) {
    this.parent = parent
    this.outputDivSelector = outputDivSelector

    this.params = new PromotionParameters(this)
    this.params.handleEvents()

    this.registerNameChangeHandler()
    this.registerDeploymentTargetChangeHandler()
    this.registerAutoPromotionToggle()
    this.registerAutoPromotionConditionHandler()
    this.registerUseAutoPromotionExample()

    this.registerDeletePromotionHandler()

    this.renderingDisabled = false
  }

  registerNameChangeHandler() {
    let handler = (e) => {
      let name = $(e.currentTarget).val()
      let promotion = SelectionRegister.getSelectedElement()

      promotion.changeName(name)
    }

    this.on("input", "[data-action=changeName]", (e) => handler(e))
  }

  registerDeploymentTargetChangeHandler() {
    let handler = (e) => {
      let deploymentTarget = $(e.currentTarget).val()
      let promotion = SelectionRegister.getSelectedElement()

      promotion.changeDeploymentTarget(deploymentTarget)
    }

    this.on("input", "[data-action=changeDeploymentTarget]", (e) => handler(e))
  }

  registerAutoPromotionConditionHandler() {
    let handler = _.debounce((promotion, condition) => {
      this.noRender(() => {
        promotion.autoPromote.setCondition(condition)
      })
    }, 500)

    this.on("input", "[data-action=changeAutoPromoteCondition]", (e) => {
      let condition = $(e.currentTarget).val()
      let promotion = SelectionRegister.getSelectedElement()

      handler(promotion, condition)
    })
  }

  registerAutoPromotionToggle() {
    this.on("click", "[data-action=enableAutoPromotion]", () => {
      let promotion = SelectionRegister.getSelectedElement()

      promotion.autoPromote.toggle()

      $(this.outputDivSelector)
        .find("[data-action=changeAutoPromoteCondition]")
        .select()
    })
  }

  registerUseAutoPromotionExample() {
    this.on("click", "[data-action=useExample]", (e) => {
      let example = $(e.currentTarget).parent().find("input").val()
      let promotion = SelectionRegister.getSelectedElement()

      promotion.autoPromote.setCondition(example)
    })
  }

  registerDeletePromotionHandler() {
    this.on("click", "[data-action=deletePromotion]", () => {
      let promotion = SelectionRegister.getSelectedElement()

      let msg = `This will also delete everything that comes after the promotion! Are you sure?`

      let isConfirmed = confirm(msg)

      if(isConfirmed) {
        promotion.pipeline.removePromotion(promotion)
      }
    })
  }

  registerParamHandlers() {
    this.on("click", "[data-action=addPromotionEnvParameter]", () => {
      let promotion = SelectionRegister.getSelectedElement()

      promotion.parameters.add()
    })

    this.on("click", "[data-action=deletePromotionEnvParamater]", (e) => {
      let promotion = SelectionRegister.getSelectedElement()
      let index = Utils.intAttr(e.currentTarget, "data-index")

      let msg = `This will remove the parameter in the promotion. Are you sure?`
      let isConfirmed = confirm(msg)

      if(isConfirmed) {
        promotion.parameters.remove(index)
      }
    })

    this.on("change", "[data-action=changePromotionParameterEnvName]", (e) => {
      let promotion = SelectionRegister.getSelectedElement()
      let index = Utils.intAttr(e.currentTarget, "data-index")
      let value = $(e.currentTarget).val()

      promotion.parameters.changeName(index, value)
    })

    this.on("change", "[data-action=changePromotionParameterEnvDescription]", (e) => {
      let promotion = SelectionRegister.getSelectedElement()
      let index = Utils.intAttr(e.currentTarget, "data-index")
      let value = $(e.currentTarget).val()

      promotion.parameters.changeDescription(index, value)
    })

    this.on("change", "[data-action=changePromotionParameterEnvDefault]", (e) => {
      let promotion = SelectionRegister.getSelectedElement()
      let index = Utils.intAttr(e.currentTarget, "data-index")
      let value = $(e.currentTarget).val()

      promotion.parameters.changeDefault(index, value)
    })

    this.on("change", "[data-action=changePromotionParameterEnvOptions]", (e) => {
      let promotion = SelectionRegister.getSelectedElement()
      let index = Utils.intAttr(e.currentTarget, "data-index")
      let value = $(e.currentTarget).val()

      promotion.parameters.changeOptions(index, value)
    })

    this.on("change", "[data-action=changePromotionParameterEnvRequired]", (e) => {
      let promotion = SelectionRegister.getSelectedElement()
      let index = Utils.intAttr(e.currentTarget, "data-index")
      let value = $(e.currentTarget).is(':checked')

      promotion.parameters.changeRequired(index, value)
    })
  }

  on(event, selector, callback) {
    let s = `${this.outputDivSelector}[data-type=promotion] ${selector}`

    this.parent.on(event, s, callback)
  }

  render(promotion) {
    if(this.renderingDisabled) return;

    Utils.preserveSelectedElement(() => {
      Utils.preserveDropdownState(this.outputDivSelector, () => {
        let html = `<div class="">
          ${PromotionConfigTemplate.name(promotion)}
          ${Features.isEnabled("deploymentTargets") ? PromotionConfigTemplate.deploymentTargets(promotion) : ""}
          ${PromotionConfigTemplate.autoPromote(promotion)}
          ${Features.isEnabled("parameterizedPromotions") ? this.params.render(promotion) : ""}
          ${PromotionConfigTemplate.deletePromotion(promotion)}
        </div>`

        $(this.outputDivSelector).html(html)
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
