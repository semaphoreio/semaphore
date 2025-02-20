export default {
  init(params) {
    return new TargetComponent(params.branch, params.pipeline_file)
  }
}

import { Validator, Rule } from './validation'

class TargetComponent {
  constructor(branch, pipelineFile) {
    this.validators = {
      branch: new Validator('branch', branch, [
        new Rule((n) => n.length < 1, 'cannot be empty')
      ]),
      pipelineFile: new Validator('pipelineFile', pipelineFile, [
        new Rule((n) => n.length < 1, 'cannot be empty')
      ])
    }

    this.handleFieldChange('branch')
    this.handleFieldChange('pipelineFile')
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
      .querySelector(`[data-validation-input="${fieldName}"]`)
      .addEventListener('input', (event) => {
        this.changeFieldValue(fieldName, event.target.value)
      })
  }
}
