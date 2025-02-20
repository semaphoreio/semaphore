
import { Validator, Rule } from "./components/validation"

export default class JustRunForm {
  static init(params) {
    return new JustRunForm(params)
  }

  constructor(params) {
    this.branchValidator = new Validator('branch', params.branch, [
      new Rule((v) => v.length < 1, 'cannot be empty')
    ])
    this.pipelineFileValidator = new Validator('pipelineFile', params.pipelineFile, [
      new Rule((v) => v.length < 1, 'cannot be empty')
    ])
    this.parameterValidators = new Map(params.parameters.map(parameter => [parameter.name, new Validator(parameter.name, parameter.value, [
      new Rule((v) => parameter.required && (!v || v.length < 1), 'cannot be empty')
    ])]))

    this.handleBranchChange()
    this.handlePipelineFileChange()
    this.handleParameterChanges()
    this.handleSubmitButton()
  }

  renderAll() {
    this.branchValidator.render()
    this.pipelineFileValidator.render()
    this.parameterValidators.forEach(
      pV => pV.render()
    )
  }

  handleBranchChange() {
    const inputField = document.querySelector('[data-validation-input="branch"]')
    if (inputField) {
      inputField.addEventListener('input', (event) => { this.changeBranchValue(event.target.value) })
    }
  }

  changeBranchValue(branchValue) {
    this.branchValidator.setValue(branchValue)
    this.branchValidator.render()
  }

  handlePipelineFileChange() {
    const inputField = document.querySelector('[data-validation-input="pipelineFile"]')
    if (inputField) {
      inputField.addEventListener('input', (event) => { this.changePipelineFileValue(event.target.value) })
    }
  }

  changePipelineFileValue(pipelineFileValue) {
    this.pipelineFileValidator.setValue(pipelineFileValue)
    this.pipelineFileValidator.render()
  }

  handleParameterChanges() {
    this.parameterValidators.forEach((_, parameterName) => { this.handleParameterChange(parameterName) })
  }

  handleParameterChange(parameterName) {
    const inputField = document.querySelector(`[data-validation-input="${parameterName}"]`)
    if (inputField) {
      inputField.addEventListener('input', (event) => { this.changeParameterValue(parameterName, event.target.value) })
    }
  }

  changeParameterValue(parameterName, parameterValue) {
    const parameterValidator = this.parameterValidators.get(parameterName)
    parameterValidator.setValue(parameterValue)
    parameterValidator.render()
  }

  validateForm() {
    const parameterValidators = Array.from(this.parameterValidators.values())

    return this.branchValidator.isValid() &&
      this.pipelineFileValidator.isValid() &&
      parameterValidators.every(parameterValidator => parameterValidator.isValid())
  }

  handleSubmitButton() {
    const submitButton = document.querySelector('[data-action="submit-form"]')
    if (!submitButton) { return; }

    submitButton.addEventListener('click', (event) => {
      if (this.validateForm()) {
        document.forms[0].submit()
      } else {
        this.renderAll()
      }
    })
  }
}
