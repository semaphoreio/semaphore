import $ from "jquery";
import _ from "lodash";

import { Section } from "../../templates/configurator/section"
import { SelectionRegister } from "../../selection_register"

export class PrologueConfig {
  constructor(parent) {
    this.parent = parent

    this.handleEvents()
  }

  handleEvents() {
    let handler = _.debounce((element, commands) => {
      this.noRender(() => {
        element.changePrologue(commands)
      })
    }, 500)

    this.on("input", "[data-action=changePrologue]", (e) => {
      let commands = $(e.currentTarget).val()
      let element = SelectionRegister.getSelectedElement()

      if(element) {
        handler(element, this.parseCommands(commands))
      }
    })
  }

  render() {
    let commandCount = this.parent.model.prologueCommands().length
    let commands = this.parent.model.prologueCommands().join("\n");

    let status = null
    if(commandCount == 1) {
      status = commandCount + " prologue command"
    } else if(commandCount > 1) {
      status = commandCount + " prologue commands"
    }

    let options = {
      title: "Prologue",
      status: status,
      errorCount: 0,
      collapsable: true
    }

    return Section.section(options, `
      <p class="f5 mb2">Executes before each job.</p>

      <textarea data-action=changePrologue
                class="form-control form-control-small w-100 f6 code"
                placeholder="Commands…"
                autocomplete="off"
                style="height:0px;overflow-y:hidden;"
                wrap="off">${commands}</textarea>
    `)
  }

  parseCommands(rawCommands) {
    return rawCommands.split("\n").filter((line) => {
      return !/^\s*$/.test(line)
    })
  }

  on(event, selector, callback) {
    this.parent.on(event, selector, callback)
  }

  noRender(cb) {
    this.parent.noRender(cb)
  }
}
