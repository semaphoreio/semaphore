export default {
  init(params) {
    return new BasicsComponent(params.name, params.description, params.url)
  }
}

import { Validator, Rule } from './validation'

class BasicsComponent {
  constructor(name, _description, _url) {
    this.validators = {
      name: new Validator('name', name, [
        new Rule((n) => n.length < 1, 'cannot be empty'),
        new Rule((n) => n.length > 255, 'must be shorter than 255 characters')
      ])
    }

    this.handleFieldChange('name')
    this.handleFieldChange('description')
  }

  isValid() {
    return Object.values(this.validators).every(v => v.isValid())
  }

  renderValidations() {
    Object.values(this.validators).forEach(v => v.render())
  }

  changeFieldValue(fieldName, fieldValue) {
    this.validators[fieldName].setValue(fieldValue)
    this.validators[fieldName].render()
  }

  handleFieldChange(fieldName) {
    document
      .querySelector(`[name="${fieldName}"]`)
      .addEventListener('input', (event) => {
        this.changeFieldValue(fieldName, event.target.value)
      })
  }
}
