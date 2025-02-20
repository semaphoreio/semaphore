import $ from "jquery";

import { Agent } from "../../models/agent"
import { Utils } from "./utils"
import { SelectionRegister } from "../../selection_register"

export class AgentConfigurator {

  //
  // Accepts one argument:
  //   parent - The parent view element, PipelineConfiguratorView or BlockConfiguratorView
  //
  constructor(parent) {
    this.parent = parent

    this.registerAgentMachineTypeHandler()
    this.registerAgentMachineImageHandler()

    this.registerAgentEnvironmentTypeHandler()
    this.registerAgentAddContainerHandler()
    this.registerAgentRemoveContainerHandler()
    this.registerAgentContainerNameChange()
    this.registerAgentContainerImageChange()
    this.registerAgentContainerEnvVarHandler()
  }

  registerAgentEnvironmentTypeHandler() {
    this.on("change", "[data-action=selectAgentEnvironmentType]", (e) => {
      let selected = $(e.currentTarget).find(":selected")
      let value    = selected.attr("value")
      let model    = SelectionRegister.getSelectedElement()

      let currentType = model.agent.environmentType()

      //
      // If nothing changed there is no reason to do anything.
      //
      if(currentType === value) {
        return
      }

      //
      // If we are changing from Docker -> <something-else> the container
      // definitions will be lost. Let's confirm this with the user.
      //
      let isConfirmed = true;

      if(currentType === Agent.ENVIRONMENT_TYPE_DOCKER) {
        let question = [
          "By changing the environment type,",
          "your container settings will be lost.",
          "Are You sure?"
        ].join(" ")

        isConfirmed = confirm(question)
      }

      //
      // If the user declined this change.
      // Render the old setting and stop further processing.
      //
      if(!isConfirmed) {
        this.render()
        return
      }

      //
      // Finally, if the change is real and the user confirmed it, modify the
      // model and trigger a re-render.
      //
      model.agent.changeEnvironmentType(value)
      this.render()
    })
  }

  registerAgentMachineTypeHandler() {
    this.on("click", "[data-action=selectAgentMachineType]", (e) => {

      //
      // If machine type is not available - exit early
      //
      if($(e.currentTarget).attr("disabled")) {
        return
      }

      let type = $(e.currentTarget).attr("data-machine-type")
      let model = SelectionRegister.getSelectedElement()

      model.agent.changeMachineType(type)
    })
  }

  registerAgentMachineImageHandler() {
    this.on("change", "[data-action=selectAgentMachineOSImage]", (e) => {
      let selected = $(e.currentTarget).find(":selected")
      let image    = selected.attr("value")
      let model    = SelectionRegister.getSelectedElement()

      model.agent.changeOSImage(image)
    })
  }

  registerAgentContainerNameChange() {
    this.on("input", "[data-action=changeContainerName]", (e) => {
      let target = $(e.currentTarget)
      let model = SelectionRegister.getSelectedElement()
      let index = Utils.intAttr(target, "data-container-index")
      let container = model.agent.containers[index]

      let name = target.val()

      this.noRender(() => {
        container.changeName(name)
      })
    })
  }

  registerAgentContainerImageChange() {
    this.on("input", "[data-action=changeContainerImage]", (e) => {
      let target = $(e.currentTarget)
      let model = SelectionRegister.getSelectedElement()
      let index = Utils.intAttr(target, "data-container-index")
      let container = model.agent.containers[index]

      let image = target.val()

      this.noRender(() => {
        container.changeImage(image)
      })
    })
  }

  registerAgentAddContainerHandler() {
    this.on("click", "[data-action=addContainerToAgent]", () => {
      let model = SelectionRegister.getSelectedElement()

      model.agent.addNewContainer()

      this.render()
    })
  }

  registerAgentRemoveContainerHandler() {
    this.on("click", "[data-action=deleteContainerFromAgent]", (e) => {
      let model = SelectionRegister.getSelectedElement()
      let index = Utils.intAttr(e.currentTarget, "data-container-index")

      let container = model.agent.containers[index]
      let isConfirmed = confirm(`Deleting ${container.name}. Are You sure?`)

      if(isConfirmed) {
        model.agent.removeContainerByIndex(index)
        this.render()
      }
    })
  }

  registerAgentContainerEnvVarHandler() {
    this.on("click", "[data-action=addContainerEnvVar]", (e) => {
      let model = SelectionRegister.getSelectedElement()
      let containerIndex = Utils.intAttr(e.currentTarget, "data-container-index")

      let container = model.agent.containers[containerIndex]

      container.envVars.addNew()

      this.render()
    })

    this.on("input", "[data-action=changeContainerEnvVar]", (e) => {
      let target         = $(e.currentTarget)
      let model          = SelectionRegister.getSelectedElement()
      let containerIndex = Utils.intAttr(target, "data-container-index")
      let envVarIndex    = Utils.intAttr(target, "data-env-var-index")
      let container      = model.agent.containers[containerIndex]

      let name = target.parent().find("input").first().val()
      let value = target.parent().find("input").last().val()

      this.noRender(() => {
        container.envVars.change(envVarIndex, name, value)
      })
    })

    this.on("click", "[data-action=removeContainerEnvVar]", (e) => {
      let model          = SelectionRegister.getSelectedElement()
      let containerIndex = Utils.intAttr(e.currentTarget, "data-container-index")
      let container      = model.agent.containers[containerIndex]
      let envVarIndex    = Utils.intAttr(e.currentTarget, "data-env-var-index")

      container.envVars.remove(envVarIndex)

      this.render()
    })
  }

  on(event, selector, callback) {
    this.parent.on(event, selector, callback)
  }

  render() {
    this.parent.render()
  }

  noRender(cb) {
    this.parent.noRender(cb)
  }
}
