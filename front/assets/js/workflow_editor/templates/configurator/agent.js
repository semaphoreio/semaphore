import { Agent } from "../../models/agent"

function containerEnvVars(containerIndex, envVars) {
  let inputs = envVars.map((e, envIndex) => `
    <div class="flex mb2">
      <div class="input-group">
        <input data-action=changeContainerEnvVar
               data-env-var-index=${envIndex}
               data-container-index=${containerIndex}
               autocomplete="off"
               id="env-var-name-${containerIndex}-${envIndex}"
               type="text"
               class="w-50 form-control form-control-small code"
               placeholder="Name"
               value="${escapeHtml(e.name)}">

        <input data-action=changeContainerEnvVar
               data-env-var-index=${envIndex}
               data-container-index=${containerIndex}
               autocomplete="off"
               id="env-var-value-${containerIndex}-${envIndex}"
               type="text"
               class="w-50 form-control form-control-small code"
               placeholder="Value"
               value="${escapeHtml(e.value)}">
      </div>

      <div data-action=removeContainerEnvVar
           data-container-index=${containerIndex}
           data-env-var-index=${envIndex}
           data-action=deleteEnvVarFromContainer
           class="flex-shrink-0 f3 fw3 pl2 pr2 nr2 black-40 hover-black pointer"
           >×</div>
    </div>
  `).join("\n")

  return `
    <div class="flex items-start">
      <div class="w-25 tr pr2" style="padding-top: 2px">
        <label class="f6 gray">env_vars</label>
      </div>

      <div class="w-75">
        ${inputs}
      </div>
    </div>
  `
}

function renderContainer(container, index, options) {
  let deletable = options.deletable || false
  let nameEditable = options.nameEditable || false

  let name =`
    <div class="flex items-center mb2">
      <div class="w-25 tr pr2">
        <label class="f6 gray">Name</label>
      </div>
      <div class="w-75">
        <input data-action=changeContainerName
               data-container-index=${index}
               autocomplete="off"
               type="text"
               class="form-control form-control-small w-100"
               placeholder="e.g. db"
               ${nameEditable ? "" : "disabled"}
               value="${container.name}">
      </div>
    </div>`

  let image = `
    <div class="flex items-center mb2">
      <div class="w-25 tr pr2">
        <label for=container-image-${index} class="f6 gray">Image</label>
      </div>
      <div class="w-75">
        <input id=container-image-${index}
               data-action=changeContainerImage
               data-container-index=${index}
               autocomplete="off"
               type="text"
               class="form-control form-control-small w-100"
               placeholder="e.g. postgres:9.6"
               value="${container.image}">
      </div>
    </div>`

  let deleteButton = ""
  if(deletable) {
    deleteButton = `<div data-action=deleteContainerFromAgent data-container-index=${index} class="flex-shrink-0 f3 fw3 ml2 nt2 nb2 pt2 pl2 pr2 nr2 black-40 hover-black pointer bl b--lighter-gray">×</div>`
  } else {
    deleteButton = `<div class="flex-shrink-0 f3 fw3 ml2 nt2 nb2 pt2 pl2 pr2 nr2 transparent">×</div>`
  }

  let hasEnvVars = !container.envVars.isEmpty()

  let klass = "flex bg-washed-gray ba b--lighter-gray pa2 br3 mv2"
  if(!deletable) {
    klass += " c-list-item-pinned"
  }

  return `
    <div class="${klass}">
      <div class="flex-auto">
        ${name}
        ${image}

        ${hasEnvVars ? containerEnvVars(index, container.envVars) : ""}

        <div class="flex items-center">
          <div class="w-25 tr pr2">
            <label class="f5 gray">&nbsp;</label>
          </div>
          <div class="w-75 pt2">
            <a data-action=addContainerEnvVar
               data-container-index=${index}
               href="#"
               class="db f6 gray">+ Add environment variable</a>
          </div>
        </div>
      </div>

      ${deleteButton}
    </div>`
}

function mainContainer(agent) {
  let container = renderContainer(agent.containers[0], 0, {
    deletable: false,
    nameEditable: false
  })

  return `
    <p class="f5 mv2">This container runs your commands</p>
    ${container}
  `
}

function attachedContainer(agent) {
  let containers = agent.containers.slice(1)

  let output = ""

  if(containers.length > 0) {
    output += `<p class='f6 mv2'>Attached via DNS</p>`

    output += containers.map((c, index) => {
      return renderContainer(c, index + 1, {
        deletable: true,
        nameEditable: true
      })
    }).join("\n")
  }

  return `
    ${output}

    <div class="pt2">
      <a data-action=addContainerToAgent href="#" class="f6">+ Add Container</a>
    </div>
  `
}

function containers(agent) {
  let docs = "https://docs.semaphoreci.com/reference/pipeline-yaml#containers"

  return `
    <div class="bt b--lighter-gray pt3 mt3">
      <div class="flex justify-between">
        <label class="db f5 gray">Containers</label>
        <a href="${docs}" target="_blank" rel="noopener" class="f6 gray">?</a>
      </div>

      ${mainContainer(agent)}
      ${attachedContainer(agent)}
    </div>
  `
}

function machineOsImage(agent) {
  let options = []
  if (agent.isInvalidImage(agent.type)) {
    options.push("")
  }

  options = options.concat(agent.availableOSImages(agent.type))

  let htmlOptions = options.map((image) => {
    return `<option value="${image}" ${image == agent.osImage ? "selected" : ""}>
      ${image}
    </option>`
  })

  return `
    <div class="bb b--lighter-gray mb3 pb3">
      <label class="db f5 gray mt2 mb1">OS Image</label>
      ${agent.isInvalidImage(agent.type) ? invalidImageWarning(agent.osImage, agent.type) : ""}
      <select name="osImage"
              data-action=selectAgentMachineOSImage
              ${htmlOptions.length <= 1 ? "disabled" : ""}
              class="form-control form-control-small w-100">
        ${htmlOptions.join("\n")}
      </select>
    </div>
  `
}

function invalidImageWarning(image, machineType) {
  return `
    <div class="flex flex-column items-center justify-center bg-washed-red mb2">
      <p class="mb0 pv2 ph3">The image <b>${image}</b> is not available for the <b>${machineType}</b> machine type.
      Please, use a valid image or select a different environment type.</p>
    </div>
  `
}

function noMachineTypesWarning() {
  return `
    <div class="flex flex-column items-center justify-center bg-washed-red mb2">
      <p class="mb0 pv2 ph3">
        There are no machine types available. You can create self-hosted agent types <a href="/self_hosted_agents">here</a>.
      </p>
    </div>
  `
}

function machineType(agent, name, size, description, zeroState) {
  let enabled = !zeroState
  return `
    <div class="flex items-center justify-between">
      <div>
        <input type="radio"
          name="agent-machine"
          data-action=selectAgentMachineType
          data-machine-type=${name}
          autocomplete="off"
          id="${name}"
          class="mr1"
          style="box-shadow: none"
          ${enabled ? "" : "disabled=\"\""}
          ${agent.type === name ? "checked=\"\"" : ""}>

        <label
          for="${name}"
          data-action=selectAgentMachineType
          data-machine-type=${name}
          class="default-tip ${enabled ? "" : "mid-gray"}"
          ${enabled ? "" : "disabled=\"\""}
          data-tippy=""
          data-original-title="${description}">${name}</label>
      </div>

      <div>
        <span class="f5 ${enabled ? "gray" : "mid-gray"}">${size}</span>
        ${enabled ? "" : "<a href=\"https://semaphoreci.com/contact\" target=\"_blank\" rel=\"noopener\" class=\"mid-gray\">On request →</a>" }
      </div>
    </div>`
}

function machineTypes(agent) {
  let types = []

  switch(agent.environmentType()) {
    case Agent.ENVIRONMENT_TYPE_LINUX_VM:
      agent.availableMachineTypes("LINUX").forEach(type => {
        types.push(machineType(
          agent,
          type,
          agent.specs(type),
          agent.specs(type),
          agent.isZeroState(type)
        ))
      })

      break
    case Agent.ENVIRONMENT_TYPE_DOCKER:
      agent.availableMachineTypes("LINUX").concat(agent.availableMachineTypes("SELF_HOSTED")).forEach(type => {
        types.push(machineType(
          agent,
          type,
          agent.specs(type),
          agent.specs(type),
          agent.isZeroState(type)
        ))
      })

      break
    case Agent.ENVIRONMENT_TYPE_MAC_VM:
      agent.availableMachineTypes("MAC").forEach(type => {
        types.push(machineType(
          agent,
          type,
          agent.specs(type),
          agent.specs(type),
          agent.isZeroState(type)
        ))
      })

      break
    case Agent.ENVIRONMENT_TYPE_SELF_HOSTED:
      agent.availableMachineTypes("SELF_HOSTED").forEach(type => {
        types.push(machineType(
          agent,
          type,
          agent.specs(type),
          agent.specs(type),
          agent.isZeroState(type)
        ))
      })
  }

  return `
    <label class="db f5 gray mt2 mb1">Machine Type</label>
    ${agent.isInvalidMachineType(agent.type) ? invalidMachineTypeWarning(agent) : ""}
    ${types.join("\n")}
  `
}

function invalidMachineTypeWarning(agent) {
  return `
    <div class="flex flex-column items-center justify-center bg-washed-red mb2">
      <p class="mb0 pv2 ph3">The <b>${agent.type}</b> agent type is not available.
      Please, use a valid agent type or use a different environment type.</p>
    </div>
  `
}

function environmentTypeSelector(agent) {
  let options = []

  let environmentType = agent.environmentType()
  if (environmentType === Agent.ENVIRONMENT_TYPE_UNKNOWN) {
    options.push({
      value: "",
      text: "",
      selected: true
    })
  }

  let availableLinuxCloudMachines = agent.availableMachineTypes("LINUX")
  if (availableLinuxCloudMachines.length > 0) {
    options.push({
      value: Agent.ENVIRONMENT_TYPE_LINUX_VM,
      text: "Linux Based Virtual Machine",
      selected: Agent.ENVIRONMENT_TYPE_LINUX_VM === environmentType
    })
  }

  let availableNacCloudMachines = agent.availableMachineTypes("MAC")
  if (availableNacCloudMachines.length > 0) {
    options.push({
      value: Agent.ENVIRONMENT_TYPE_MAC_VM,
      text: "Mac Based Virtual Machine",
      selected: Agent.ENVIRONMENT_TYPE_MAC_VM === environmentType
    })
  }

  let availableSelfHostedTypes = agent.availableMachineTypes("SELF_HOSTED")
  if (availableSelfHostedTypes.length > 0) {
    options.push({
      value: Agent.ENVIRONMENT_TYPE_SELF_HOSTED,
      text: "Self-Hosted Machine",
      selected: Agent.ENVIRONMENT_TYPE_SELF_HOSTED === environmentType
    })
  }

  options.push({
    value: Agent.ENVIRONMENT_TYPE_DOCKER,
    text: "Docker Container(s)",
    selected: Agent.ENVIRONMENT_TYPE_DOCKER === environmentType
  })

  let htmlOptions = options.map((o) => {
    return `<option value="${o.value}" ${o.selected ? "selected" : ""}>
      ${o.text}
    </option>`
  })

  return `
    <label for=environmentType class="db f5 gray mb1">Environment Type</label>

    <div class="bb b--lighter-gray pb3">
      <select name="environmentType"
              data-action=selectAgentEnvironmentType
              class="form-control form-control-small w-100">
        ${htmlOptions}
      </select>
    </div>
  `
}

function unknownEnvironmentTypeWarning(machineType) {
  return `
    <div class="flex flex-column items-center justify-center bg-washed-red mb2">
      <p class="mb0 pv2 ph3">The machine type <b>${machineType}</b> is not available.
      Please, select a valid environment type.</p>
    </div>
  `
}

//
// Rendering the content of the Agent configuration in the config panels.
//
function render(agent) {
  let environmentType = agent.environmentType()
  let isUnknown = environmentType === Agent.ENVIRONMENT_TYPE_UNKNOWN
  let isDocker = environmentType === Agent.ENVIRONMENT_TYPE_DOCKER
  let isSelfHosted = environmentType === Agent.ENVIRONMENT_TYPE_SELF_HOSTED

  if (environmentType === Agent.ENVIRONMENT_TYPE_UNAVAILABLE) {
    return noMachineTypesWarning()
  }

  return `
    ${isUnknown ? unknownEnvironmentTypeWarning(agent.type) : ""}
    ${environmentTypeSelector(agent)}
    ${isDocker || isSelfHosted || isUnknown ? "" : machineOsImage(agent)}
    ${isUnknown ? "" : machineTypes(agent)}
    ${isDocker ? containers(agent) : ""}
  `;
}

export var AgentConfig = {
  render: render
}
