export default {
  init(parameters) {
    return new ParametersComponent(parameters)
  }
}

class Parameter {
  static empty_values() {
    return {
      name: "",
      description: "",
      default_value: "",
      options: [],
      required: false,
      validations: []
    }
  }

  constructor(...kwargs) {
    Object.assign(this, Parameter.empty_values(), ...kwargs)
    this.options = this.options.join("\n")
  }

  validate() {
    const nameMsg = this.nameValidationMsg()

    this.validations = []
    if (nameMsg) { this.validations.push({ field: 'name', message: nameMsg }) }
  }

  isValid() {
    this.validate()
    return this.validations.length === 0
  }

  nameValidationMsg() {
    const envVarNameRegex = /^[A-Z_]{1,}[A-Z0-9_]*$/g
    if (!this.name || this.name.length < 1) { return 'Name can\'t be blank' }
    if (!this.name.match(envVarNameRegex)) { return 'Name must be a valid environment variable name' }
  }
}

class ParametersComponent {
  constructor(parameters) {
    this.parameters = parameters.map(parameter => new Parameter(parameter))

    this.handleAddNewButton()
    this.renderParameters()
  }

  isValid() {
    return this.parameters.every(parameter => parameter.isValid())
  }

  renderValidations() {
    clearParameterValidations()
    this.parameters.forEach(parameter => parameter.validate())
    this.parameters.forEach((parameter, index) => {
      if (parameter.validations.length > 0) {
        renderParameterValidations(parameter.validations, index)
      }
    })
  }

  addNewParameter() {
    this.parameters.push(new Parameter())
  }

  updateParameter(index, key, value) {
    this.parameters[index][key] = value
  }

  changeParameterRequired(index, value) {
    this.parameters[index]['required'] = value
  }

  deleteParameter(index) {
    this.parameters.splice(index, 1)
  }

  handleAddNewButton() {
    document
      .querySelectorAll('[data-action=addNewParameter]')
      .forEach((element) => element.addEventListener('click', (event) => {
        event.preventDefault()
        this.addNewParameter()
        this.renderParameters()
      }))
  }

  validateForm() {
    allSections.forEach(sectionName => this.components[sectionName].renderValidations())
    return allSections.every(sectionName => this.components[sectionName].isValid())
  }

  renderParameters(showValidations = false) {
    const container = document.querySelector('[data-target=parameters]')
    if (!container) return

    container.innerHTML = renderParameters(this.parameters)
    container.querySelectorAll('[data-action=deleteParameter]')
      .forEach((element) => {
        element.addEventListener('click', (event) => {
          event.preventDefault()
          this.deleteParameter(element.dataset.index)
          this.renderParameters(showValidations)
        })
      })

    container.querySelectorAll('[data-action=updateParameter]')
      .forEach((element) => {
        element.addEventListener('input', (event) => {
          this.updateParameter(element.dataset.index, element.dataset.field, element.value)
          this.renderValidations()
        })
      })


    container.querySelectorAll('[data-action=changeParameterRequired]')
      .forEach((element) => {
        element.addEventListener('change', (event) => {
          this.changeParameterRequired(element.dataset.index, event.target.checked)
          this.renderValidations()
        })
      })
  }
}

function getValue(index, field) {
  const element = document.getElementById(`parameter_${index}_${field}`)
  return element ? element.value : ""
}

function renderParameters(parameters, showValidation = false) {
  if (parameters.length < 1) { return `No parameters are defined.` }
  return parameters.map((p, index) => renderParameter(p, index, showValidation)).join("\n")
}

function renderParameter(parameter, index) {
  return `
      <div class="relative flex bg-washed-gray ba b--lighter-gray pa2 br3 mv2"
           data-component="parameter" data-index="${index}">
        <div class="flex-auto" data-validation="parameter" data-validation-index=${index}>
          ${renderName(parameter, index)}
          ${renderDescription(parameter, index)}
          ${renderOptions(parameter, index)}

          ${renderRequired(parameter, index)}
          ${renderDefaultValue(parameter, index)}
        </div>

        <div data-action="deleteParameter" data-index="${index}"
              class="flex-shrink-0 f3 fw3 ml2 nt2 nb2 pt2 ph2 nr2 black-40 hover-black pointer bl b--lighter-gray">
          ×
        </div>
      </div>
    `;
}

function renderName(parameter, index) {
  return `
      <div>
        <div>
          <label class="f6 gray">Name</label>
        </div>
        <div>
          <input data-action="updateParameter"
                  data-field="name"
                  data-index=${index}
                  autocomplete="off"
                  type="text"
                  id="parameter_${index}_name"
                  name="parameters[${index}][name]"
                  class="form-control form-control-small w-100"
                  value="${escapeHtml(parameter.name) || ""}"
                  placeholder="e.g. SERVER_IP">
          <div class="f5 mv1 red" data-validation-message="name"></div>
        </div>
      </div>
    `;
}

function renderDescription(parameter, index) {
  return `
      <div class="mt2">
        <div>
          <label class="f6 gray">Description</label>
        </div>
        <div>
          <input data-action="updateParameter"
                 data-field="description"
                 data-index=${index}
                 autocomplete="off"
                 type="text"
                 id="parameter_${index}_description"
                 name="parameters[${index}][description]"
                 value="${escapeHtml(parameter.description) || ""}"
                 class="form-control form-control-small w-100"
                 placeholder="e.g. Server IP where we are deploying.">
          <div class="f5 mv1 red" data-validation-message="description"></div>
        </div>
      </div>
    `;
}

function renderDefaultValue(parameter, index) {
  return `
      <div class="mt1">
        <div>
          <label class="f6 gray">Default Value <small class=f7>(used by scheduled runs)</small></label>
        </div>
        <div>
          <input data-action="updateParameter"
                 data-field="default_value"
                 data-index=${index}
                 autocomplete="off"
                 type="text"
                 id="parameter_${index}_default_value"
                 name="parameters[${index}][default_value]"
                 value="${escapeHtml(parameter.default_value) || ""}"
                 class="form-control form-control-small w-100"
                 placeholder="e.g. 1.2.3.4">
          <div class="f5 mv1 red" data-validation-message="default_value"></div>
        </div>
      </div>
    `;
}

function renderOptions(parameter, index) {
  return `
      <div class="mt2">
        <div>
          <label class="f6 gray">Valid Options <small class=f7>(leave empty to allow all values)</small></label>
        </div>
        <div>
          <textarea data-action="updateParameter"
                    data-field="options"
                    data-index=${index}
                    autocomplete="off"
                    style="min-height: 70px"
                    id="parameter_${index}_options"
                    name="parameters[${index}][options]"
                    class="form-control form-control-small w-100 f6"
                    placeholder="1.2.3.4\n3.4.5.6\n…" style="height:48px;overflow-y:hidden;"
                    wrap="off">${escapeHtml(parameter.options)}</textarea>
          <div class="f5 mv1 red" data-validation-message="options"></div>
        </div>
      </div>
    `;
}

function renderRequired(parameter, index) {
  return `
      <div class="mt2">
        <div>
          <input data-action="changeParameterRequired"
                 data-field="required"
                 type="checkbox"
                 data-index=${index}
                 id="parameter_${index}_required"
                 name="parameters[${index}][required]"
                 ${parameter.required ? 'checked=true' : ""}>
          <label class="f6 gray">This is a required parameter</label>
          <div class="f5 mv1 red" data-validation-message="required"></div>
        </div>
      </div>
    `;
}

function renderParameterValidations(validations, index) {
  const validationContext = document.querySelector(`[data-validation="parameter"][data-validation-index="${index}"]`)
  if (!validationContext) { return }

  validations.forEach((validation) => {
    renderParameterFieldValidation(validationContext, validation)
  })
}

function renderParameterFieldValidation(validationContext, validation) {
  const messageElement = validationContext.querySelector(`[data-validation-message="${validation.field}"]`)
  const inputElement = validationContext.querySelector(`[data-field="${validation.field}"]`)

  if (messageElement && inputElement) {
    messageElement.innerText = validation.message
    inputElement.classList.add(...["red", "bg-washed-red"])
  }
}

function clearParameterValidations() {
  document
    .querySelectorAll(`[data-validation="parameter"] [data-field]`)
    .forEach((element) => { element.classList.remove(...["bg-washed-red", "red"]) })

  document
    .querySelectorAll(`[data-validation="parameter"] [data-validation-message]`)
    .forEach((element) => { element.innerText = "" })
}
