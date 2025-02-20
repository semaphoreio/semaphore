export class Rule {
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

export class Validator {
  constructor(fieldName, fieldValue, rules) {
    this.fieldName = fieldName
    this.fieldValue = fieldValue
    this.rules = rules
  }

  getValue() { return this.fieldValue }
  setValue(newValue) { this.fieldValue = newValue }
  isValid() { return !(this.message()) }

  message() {
    for (const rule of this.rules) {
      const message = rule.validate(this.fieldValue)
      if (message) { return message }
    }
    return ''
  }

  render() {
    const message = this.message()

    if (message) {
      showValidationMessage(this.fieldName, message)
    } else {
      hideValidationMessage(this.fieldName)
    }
  }
}

function showValidationMessage(fieldName, message) {
  const validationContext = document.querySelector(`[data-validation="${fieldName}"]`)
  const validationInput = validationContext.querySelector(`[data-validation-input="${fieldName}"]`)
  const validationMessage = validationContext.querySelector(`[data-validation-message="${fieldName}"]`)

  validationInput.classList.add('bg-washed-red', 'red')
  validationMessage.innerHTML = message
  validationMessage.classList.remove('dn')
}

function hideValidationMessage(fieldName) {
  const validationContext = document.querySelector(`[data-validation="${fieldName}"]`)
  const validationInput = validationContext.querySelector(`[data-validation-input="${fieldName}"]`)
  const validationMessage = validationContext.querySelector(`[data-validation-message="${fieldName}"]`)

  validationInput.classList.remove('bg-washed-red', 'red')
  validationMessage.innerHTML = ''
  validationMessage.classList.add('dn')
}
