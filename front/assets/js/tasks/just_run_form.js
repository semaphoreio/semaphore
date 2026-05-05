
import { Validator, Rule } from "./components/validation"
import { TargetParams } from '../workflow_view/target_params'
import {
  MAX_PARAM_VALUE_LENGTH,
  MAX_REGEX_PATTERN_LENGTH,
  byteLength,
} from "./limits"

export { MAX_PARAM_VALUE_LENGTH, MAX_REGEX_PATTERN_LENGTH }

export default class JustRunForm {
  static init(params) {
    return new JustRunForm(params)
  }

  constructor(params) {
    const referenceName = params.referenceName || 'Enter a branch or tag name…';
    const referenceType = params.referenceType || 'branch';

    this.referenceNameValidator = new Validator('referenceName', referenceName, [
      new Rule((v) => v.length < 1, 'cannot be empty')
    ])
    this.pipelineFileValidator = new Validator('pipelineFile', params.pipelineFile, [
      new Rule((v) => v.length < 1, 'cannot be empty')
    ])
    this.parameterValidators = new Map(params.parameters.map(parameter => [parameter.name, new Validator(parameter.name, parameter.value, [
      new Rule((v) => parameter.required && (!v || v.length < 1), 'cannot be empty'),
      new Rule((v) => valueTooLong(v), `value exceeds maximum length of ${MAX_PARAM_VALUE_LENGTH} bytes`),
      new Rule(() => patternTooLong(parameter), `regex pattern exceeds maximum length of ${MAX_REGEX_PATTERN_LENGTH} bytes`),
      new Rule((v) => regexMismatch(parameter, v), 'value does not match required format')
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
      this.renderAll()

      if (this.validateForm()) {
        document.forms[0].submit()
      }
    })
  }

  initializeParameterSelects() {
    TargetParams.init('[data-parameter-select]')
  }
}

export function valueTooLong(value) {
  return typeof value === 'string' && byteLength(value) > MAX_PARAM_VALUE_LENGTH
}

export function patternTooLong(parameter) {
  return parameter.validate_input_format
    && typeof parameter.regex_pattern === 'string'
    && byteLength(parameter.regex_pattern) > MAX_REGEX_PATTERN_LENGTH
}

export function regexMismatch(parameter, value) {
  if (!parameter) { return false }
  if (!parameter.validate_input_format) { return false }
  if (!parameter.regex_pattern) { return false }
  if (patternTooLong(parameter)) { return false }
  if (!value || value.length < 1) { return false }
  if (valueTooLong(value)) { return false }

  let regex
  try {
    regex = new RegExp(parameter.regex_pattern)
  } catch (_err) {
    return false
  }
  return !regex.test(value)
}
