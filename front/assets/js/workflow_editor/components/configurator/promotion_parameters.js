import $ from "jquery";
import { PromotionParametersTemplate } from "../../templates/configurator/promotion_params"
import { SelectionRegister }      from "../../selection_register"
import { Utils }                  from "./utils"

export class PromotionParameters {
  constructor(parent) {
    this.parent = parent
  }

  handleEvents() {
    this.on("click", "[data-action=addPromotionEnvParameter]", () => {
      let promotion = SelectionRegister.getSelectedElement()

      promotion.parameters.add()
    })

    this.on("click", "[data-action=deletePromotionEnvParamater]", (e) => {
      let promotion = SelectionRegister.getSelectedElement()
      let index = Utils.intAttr(e.currentTarget, "data-index")

      let msg = `This will remove the parameter in the promotion. Are you sure?`
      let isConfirmed = confirm(msg)

      if(!isConfirmed) {
        return;
      }

      promotion.parameters.remove(index)
    })

    this.on("change", "[data-action=changePromotionParameterEnvName]", (e) => {
      let promotion = SelectionRegister.getSelectedElement()
      let index = Utils.intAttr(e.currentTarget, "data-index")
      let value = $(e.currentTarget).val()

      this.noRender(() => {
        promotion.parameters.changeName(index, value)
      })
    })

    this.on("change", "[data-action=changePromotionParameterEnvDescription]", (e) => {
      let promotion = SelectionRegister.getSelectedElement()
      let index = Utils.intAttr(e.currentTarget, "data-index")
      let value = $(e.currentTarget).val()

      this.noRender(() => {
        promotion.parameters.changeDescription(index, value)
      })
    })

    this.on("change", "[data-action=changePromotionParameterEnvDefault]", (e) => {
      let promotion = SelectionRegister.getSelectedElement()
      let index = Utils.intAttr(e.currentTarget, "data-index")
      let value = $(e.currentTarget).val()

      this.noRender(() => {
        promotion.parameters.changeDefault(index, value)
      })
    })

    this.on("change", "[data-action=changePromotionParameterEnvOptions]", (e) => {
      let promotion = SelectionRegister.getSelectedElement()
      let index = Utils.intAttr(e.currentTarget, "data-index")
      let value = $(e.currentTarget).val()
      console.log(value)
      let options = value.split("\n").map((l) => l.trim()).filter((l) => l !== "")
      console.log(options)

      this.noRender(() => {
        promotion.parameters.changeOptions(index, options)
      })
    })

    this.on("change", "[data-action=changePromotionParameterEnvRequired]", (e) => {
      let promotion = SelectionRegister.getSelectedElement()
      let index = Utils.intAttr(e.currentTarget, "data-index")
      let value = $(e.currentTarget).is(':checked')

      promotion.parameters.changeRequired(index, value)
    })
  }

  on(event, selector, callback) {
    this.parent.on(event, selector, callback)
  }

  render(promotion) {
    return PromotionParametersTemplate.render(promotion)
  }

  noRender(cb) {
    this.parent.noRender(cb)
  }

}
