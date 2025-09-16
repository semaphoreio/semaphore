
import { Validator, Rule } from "./components/validation"
import { TargetParams } from '../workflow_view/target_params'

export default class JustRunForm {
  static init(params) {
    return new JustRunForm(params)
  }

  constructor(params) {
    // Handle both legacy branch parameter and new reference parameters
    const referenceName = params.referenceName || params.branch || '';
    const referenceType = params.referenceType || 'branch';

    this.referenceNameValidator = new Validator('referenceName', referenceName, [
      new Rule((v) => v.length < 1, 'cannot be empty')
    ])
    this.pipelineFileValidator = new Validator('pipelineFile', params.pipelineFile, [
      new Rule((v) => v.length < 1, 'cannot be empty')
    ])
    this.parameterValidators = new Map(params.parameters.map(parameter => [parameter.name, new Validator(parameter.name, parameter.value, [
      new Rule((v) => parameter.required && (!v || v.length < 1), 'cannot be empty')
    ])]))

    this.currentReferenceType = referenceType
    this.handleReferenceTypeChange()
    this.handleReferenceNameChange()
    this.handlePipelineFileChange()
    this.handleParameterChanges()
    this.handleSubmitButton()
    this.updateReferenceLabel()
    this.initializeParameterSelects()
  }

  renderAll() {
    this.referenceNameValidator.render()
    this.pipelineFileValidator.render()
    this.parameterValidators.forEach(
      pV => pV.render()
    )
  }

  handleReferenceTypeChange() {
    const referenceTypeInputs = document.querySelectorAll('[data-validation-input="referenceType"]')
    referenceTypeInputs.forEach(input => {
      input.addEventListener('change', (event) => {
        this.changeReferenceType(event.target.value)
      })
    })
  }

  changeReferenceType(referenceType) {
    this.currentReferenceType = referenceType
    this.updateReferenceLabel()
  }

  updateReferenceLabel() {
    const labelElement = document.querySelector('[data-reference-label]')
    if (labelElement) {
      labelElement.textContent = this.currentReferenceType === 'tag' ? 'Tag' : 'Branch'
    }
  }

  handleReferenceNameChange() {
    const inputField = document.querySelector('[data-validation-input="referenceName"]')
    if (inputField) {
      inputField.addEventListener('input', (event) => { this.changeReferenceNameValue(event.target.value) })
    }
  }

  changeReferenceNameValue(referenceNameValue) {
    this.referenceNameValidator.setValue(referenceNameValue)
    this.referenceNameValidator.render()
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

    return this.referenceNameValidator.isValid() &&
      this.pipelineFileValidator.isValid() &&
      parameterValidators.every(parameterValidator => parameterValidator.isValid())
  }

  handleSubmitButton() {
    const submitButton = document.querySelector('[data-action="submit-form"]')
    if (!submitButton) { return; }

    submitButton.addEventListener('click', () => {
      if (this.validateForm()) {
        document.forms[0].submit()
      } else {
        this.renderAll()
      }
    })
  }

  initializeParameterSelects() {
    TargetParams.init('[data-parameter-select]')
  }
}
