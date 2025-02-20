import $ from "jquery";
import _ from "lodash";

import { Section } from "../../templates/configurator/section"
import { SelectionRegister } from "../../selection_register"

export class EpilogueConfig {
  constructor(parent) {
    this.parent = parent

    this.handleEvents()
  }

  handleEvents() {
    let alwaysHandler = _.debounce((element, commands) => {
      this.noRender(() => { element.changeEpilogueAlways(commands) })
    }, 500)

    let onPassHandler = _.debounce((element, commands) => {
      this.noRender(() => { element.changeEpilogueOnPass(commands) })
    }, 500)

    let onFailHandler = _.debounce((element, commands) => {
      this.noRender(() => { element.changeEpilogueOnFail(commands) })
    }, 500)

    this.on("input", "[data-action=changeEpilogueAlways]", (e) => {
      let commands = $(e.currentTarget).val()
      let element = SelectionRegister.getSelectedElement()

      if(!element) { return }

      alwaysHandler(element, this.parseCommands(commands))
    })

    this.on("input", "[data-action=changeEpilogueOnPass]", (e) => {
      let commands = $(e.currentTarget).val()
      let element = SelectionRegister.getSelectedElement()

      if(!element) { return }

      onPassHandler(element, this.parseCommands(commands))
    })

    this.on("input", "[data-action=changeEpilogueOnFail]", (e) => {
      let commands = $(e.currentTarget).val()
      let element = SelectionRegister.getSelectedElement()

      if(!element) { return }

      onFailHandler(element, this.parseCommands(commands))
    })
  }

  render() {
    let model = this.parent.model

    let always = model.epilogueAlwaysCommands()
    let onPass = model.epilogueOnPassCommands()
    let onFail = model.epilogueOnFailCommands()

    let commandCount = always.length + onPass.length + onFail.length

    let status = null
    if(commandCount == 1) {
      status = commandCount + " epilogue command"
    } else if(commandCount > 1) {
      status = commandCount + " epilogue commands"
    }

    let options = {
      title: "Epilogue",
      status: status,
      errorCount: 0,
      collapsable: true
    }

    return Section.section(options, `
      <p class="f5 mb2">
        Executes after each job. First, the <code class="gray">always</code>
        commands are executed, followed by the
        <code class="gray">on_pass</code> or
        <code class="gray">on_fail</code>.</p>

      <div class="mv2">
        <label for=epilogueAlways class="f5 gray db mb1">Execute always</label>

        <textarea id="epilogueAlways"
                  data-action=changeEpilogueAlways
                  autocomplete="off"
                  class="form-control form-control-small w-100 f6 code"
                  placeholder="Commands…"
                  style="height:0px;overflow-y:hidden;"
                  wrap="off">${always.join("\n")}</textarea>
      </div>

      <div class="mv2">
        <label for="epilogueOnPass" class="f5 gray db mb1">If job has passed</label>

        <textarea id=epilogueOnPass
                  data-action=changeEpilogueOnPass
                  class="form-control form-control-small w-100 f6 code"
                  placeholder="Commands…"
                  autocomplete="off"
                  style="height:0px;overflow-y:hidden;"
                  wrap="off">${onPass.join("\n")}</textarea>
      </div>

      <div class="mv2">
        <label for=epilogueOnFail class="f5 gray db mb1">If job has failed</label>

        <textarea id=epilogueOnFail
                  data-action=changeEpilogueOnFail
                  class="form-control form-control-small w-100 f6 code"
                  placeholder="Commands…"
                  autocomplete="off"
                  style="height:0px;overflow-y:hidden;"
                  wrap="off">${onFail.join("\n")}</textarea>
      </div>
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
