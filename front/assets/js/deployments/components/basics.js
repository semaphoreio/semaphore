export default {
  init(params) {
    return new BasicsComponent(params.name, params.description, params.url)
  }
}

const Rule = class {
  constructor(predicate, message) {
    this.predicate = predicate
    this.message = message
  }

  validate(value) {
    if (this.predicate(value)) {
      return this.message
    }
    return null
  }
}

const Validator = class {
  constructor(value, rules) {
    this.value = value
    this.rules = rules
  }

  setValue(newValue) { this.value = newValue }
  isValid() { return !(this.message()) }

  message() {
    for (const rule of this.rules) {
      const message = rule.validate(this.value)
      if (message) { return message }
    }
    return ''
  }
}

class BasicsComponent {
  constructor(name, _description, _url) {
    this.validators = {
      name: new Validator(name, [
        new Rule((n) => n.length < 1, 'cannot be empty'),
        new Rule((n) => n.length > 255, 'must be shorter than 255 characters'),
        new Rule((n) => !(/^[A-Za-z0-9_\.\-]+$/.exec(n)), 'must contain only alphanumericals, dashes, underscores or dots'),
      ])
    }

    this.handleFieldChange('name')
    this.handleFieldChange('description')
    this.handleFieldChange('url')
  }

  isValid() {
    return Object.values(this.validators).every(v => v.isValid())
  }

  renderValidations() {
    for (const [field, validator] of Object.entries(this.validators)) {
      this.renderFieldValidation(field, validator)
    }
  }

  renderFieldValidation(field, validator) {
    const message = validator.message()

    if (message) {
      this.showValidationMessage(field, message)
    } else {
      this.hideValidationMessage(field)
    }
  }

  showValidationMessage(field, message) {
    const validationContext = document.querySelector(`[data-validation="${field}"]`)
    const validationInput = validationContext.querySelector(`[data-validation-input="${field}"]`)
    const validationMessage = validationContext.querySelector(`[data-validation-message="${field}"]`)

    validationInput.classList.add('bg-washed-red', 'red')
    validationMessage.innerHTML = message
    validationMessage.classList.remove('dn')
  }

  hideValidationMessage(field) {
    const validationContext = document.querySelector(`[data-validation="${field}"]`)
    const validationInput = validationContext.querySelector(`[data-validation-input="${field}"]`)
    const validationMessage = validationContext.querySelector(`[data-validation-message="${field}"]`)

    validationInput.classList.remove('bg-washed-red', 'red')
    validationMessage.innerHTML = ''
    validationMessage.classList.add('dn')
  }

  changeFieldValue(field, value) {
    this.validators[field].setValue(value)
    this.renderFieldValidation(field, this.validators[field])
  }

  handleFieldChange(field) {
    document
      .querySelector(`[name="target[${field}]"]`)
      .addEventListener('input', (event) => {
        this.changeFieldValue(field, event.target.value)
      })
  }
}
