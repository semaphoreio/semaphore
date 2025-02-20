import $ from "jquery"

import { TabsTemplate } from "../templates/tabs"
import { SelectionRegister } from "../selection_register"

export class Tabs {
  constructor(editor, outputDivSelector, canDismissAndExit) {
    this.editor = editor
    this.outputDivSelector = outputDivSelector

    this.active = "visual"
    this.pipeline = null
    this.canDismissAndExit = canDismissAndExit

    this.handleTabClicks()
  }

  isVisualActive() {
    return this.active === "visual"
  }

  setActive(target, pipeline) {
    this.active = target
    this.pipeline = pipeline
  }

  handleTabClicks() {
    let selector = `${this.outputDivSelector} [data-action=changeTab]`

    this.editor.on("click", selector, (e) => {
      e.stopPropagation()

      let target = $(e.currentTarget).attr("data-target")

      switch(target) {
        case "visual":
          this.setActive("visual", null)
          break

        case "code": {
          let uid = $(e.currentTarget).attr("data-pipeline-uid")
          let pipeline = SelectionRegister.lookup(uid)

          this.setActive("code", pipeline)
          break
        }

        default:
          throw "Unknown tab target"
      }

      this.editor.update()
    })
  }

  update() {
    $(this.outputDivSelector).html(TabsTemplate.render(this))
  }

}
