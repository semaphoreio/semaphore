export default {
  init(prefixId) {
    if (prefixId === "organization_pfc") {
      return new AgentComponent("agent_config", InjectedDataByBackend.PreFlightChecks.AgentEnvs)
    }
    if (prefixId === "project_pfc") {
      return new AgentComponent("project_pfc_agent", InjectedDataByBackend.PreFlightChecks.AgentEnvs)
    }
  }
}

class AgentComponent {
  constructor(prefix, agentEnvs) {
    this.envTypeElement = document.getElementById(`${prefix}_env_type`)
    this.machineTypeElement = document.getElementById(`${prefix}_machine_type`)
    this.osImageElement = document.getElementById(`${prefix}_os_image`)

    this.agentEnvs = agentEnvs
    this.initalizeHandles()
    renderOnInit(this)
  }

  currentEnv() { return this.agentEnvs[this.currentEnvType()] }
  currentEnvType() { return this.envTypeElement.value }
  currentMachineType() { return this.machineTypeElement.value }

  defaultOsImage() {
    return this.currentEnv().default_os_image
  }

  machineTypes() {
    const machineTypes = Object.values(this.currentEnv().machine_types)
    return machineTypes.sort((mt1, mt2) => mt1.type.localeCompare(mt2.type))
  }

  osImages() {
    const machineType = this.currentMachineType()
    const machine = this.currentEnv().machine_types[machineType]
    return machine ? machine.os_images : []
  }

  initalizeHandles() {
    this.handleEnvTypeChanges()
    this.handleMachineTypeChanges()
    this.handleAgentFlagToggles()
  }

  handleEnvTypeChanges() {
    this.envTypeElement.addEventListener("input", (event) => {
      renderMachineTypes(this)
      renderOsImages(this)
    })
  }

  handleMachineTypeChanges() {
    this.machineTypeElement.addEventListener("input", (event) => {
      renderOsImages(this)
    })
  }

  handleAgentFlagToggles(prefix) {
    const toggle = document.querySelector('[data-element="agent-config-toggle"]')
    const container = document.querySelector('[data-element="agent-config-container"]')
    if (!toggle || !container) return

    toggle.addEventListener("input", (event) => {
      if (event.target.checked) {
        container.classList.remove('dn')
      } else {
        container.classList.add('dn')
      }
    })

    if (!toggle.checked) {
      container.classList.add('dn')
    }
  }
}

function renderOnInit(component) {
  const htmlElement = component.osImageElement
  const envType = component.currentEnvType()

  toggleVisibility(htmlElement, envType === 'SELF_HOSTED')
}

function renderMachineTypes(component) {
  const htmlElement = component.machineTypeElement
  const machineTypes = component.machineTypes()
  const machineTypeOptions = machineTypes.map((mt) => machineTypeOption(mt))

  clearOptions(htmlElement)
  renderOptions(htmlElement, machineTypeOptions)
}

function machineTypeOption(machineType) {
  const label = machineType.specs ? `${machineType.type} (${machineType.specs})` : machineType.type
  return { label: label, value: machineType.type }
}

function renderOsImages(component) {
  const htmlElement = component.osImageElement
  const envType = component.currentEnvType()

  const defaultOsImage = component.defaultOsImage()
  const osImages = component.osImages()
  const osImageOptions = osImages.map((mt) => osImageOption(mt))

  clearOptions(htmlElement)
  renderOptions(htmlElement, osImageOptions)
  toggleVisibility(htmlElement, envType === 'SELF_HOSTED')
  selectDefaultOption(htmlElement, osImages, defaultOsImage)
}

function osImageOption(osImage) {
  return { label: osImage, value: osImage }
}

function clearOptions(htmlElement) {
  while (htmlElement.firstChild) {
    htmlElement.removeChild(htmlElement.lastChild)
  }
}

function renderOptions(htmlElement, options) {
  options.forEach((o) => renderOption(htmlElement, o))
}

function renderOption(htmlElement, option) {
  let optionElement = document.createElement("option")
  optionElement.setAttribute("value", option.value)
  optionElement.innerText = option.label

  htmlElement.append(optionElement)
}

function toggleVisibility(htmlElement, predicate) {
  const container = htmlElement.parentElement
  const emptyOption = { label: "", value: "" }

  if (predicate) {
    container.setAttribute('style', 'display: none;')
    renderOption(htmlElement, emptyOption)

  } else {
    container.setAttribute('style', '')
  }
}

function selectDefaultOption(htmlElement, options, defaultOption) {
  if (options.includes(defaultOption)) {
    htmlElement.value = defaultOption
  }
}
