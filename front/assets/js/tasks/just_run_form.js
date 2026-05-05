
import { Validator, Rule } from "./components/validation"
import { TargetParams } from '../workflow_view/target_params'
import { regexMatchWithTimeout } from "./safe_regex"

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
    this.parametersByName = new Map(params.parameters.map(parameter => [parameter.name, parameter]))
    this.parameterValidators = new Map(params.parameters.map(parameter => [parameter.name, new Validator(parameter.name, parameter.value, [
      new Rule((v) => parameter.required && (!v || v.length < 1), 'cannot be empty'),
      new Rule((v) => valueTooLong(v), `value exceeds maximum length of ${MAX_PARAM_VALUE_LENGTH} characters`),
      new Rule(() => patternTooLong(parameter), `regex pattern exceeds maximum length of ${MAX_REGEX_PATTERN_LENGTH} characters`)
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

  syncFormValid() {
    const parameterValidators = Array.from(this.parameterValidators.values())

    return this.referenceNameValidator.isValid() &&
      this.pipelineFileValidator.isValid() &&
      parameterValidators.every(parameterValidator => parameterValidator.isValid())
  }

  async validateForm() {
    return this.syncFormValid() && await this.renderRegexValidations()
  }

  async renderRegexValidations() {
    const validations = await Promise.all(
      Array
        .from(this.parameterValidators.entries())
        .map(async ([parameterName, validator]) => {
          const parameter = this.parametersByName.get(parameterName)
          const message = await regexValidationMessage(parameter, validator.getValue())

          return { parameterName, message }
        })
    )

    validations.forEach(({ parameterName, message }) => {
      if (message) {
        showParameterValidationMessage(parameterName, message)
      } else {
        hideParameterValidationMessage(parameterName)
      }
    })

    return validations.every(({ message }) => !message)
  }

  handleSubmitButton() {
    const submitButton = document.querySelector('[data-action="submit-form"]')
    if (!submitButton) { return; }

    submitButton.addEventListener('click', async () => {
      this.renderAll()

      if (await this.validateForm()) {
        document.forms[0].submit()
      }
    })
  }

  initializeParameterSelects() {
    TargetParams.init('[data-parameter-select]')
  }
}

export const MAX_REGEX_PATTERN_LENGTH = 512
export const MAX_PARAM_VALUE_LENGTH = 4096

export function valueTooLong(value) {
  return typeof value === 'string' && value.length > MAX_PARAM_VALUE_LENGTH
}

export function patternTooLong(parameter) {
  return parameter.validate_input_format
    && typeof parameter.regex_pattern === 'string'
    && parameter.regex_pattern.length > MAX_REGEX_PATTERN_LENGTH
}

export function regexMismatch(parameter, value, options = {}) {
  return regexResult(parameter, value, options).then(result => result.status === 'mismatch')
}

export function regexValidationMessage(parameter, value, options = {}) {
  return regexResult(parameter, value, options).then((result) => {
    if (result.status === 'mismatch') { return 'value does not match required format' }
    if (result.status === 'timeout') { return 'value could not be validated quickly enough' }
    return ''
  })
}

function showParameterValidationMessage(fieldName, message) {
  const validationContext = document.querySelector(`[data-validation="${fieldName}"]`)
  if (!validationContext) { return }

  const validationInput = validationContext.querySelector(`[data-validation-input="${fieldName}"]`)
  const validationMessage = validationContext.querySelector(`[data-validation-message="${fieldName}"]`)
  if (!validationInput || !validationMessage) { return }

  validationInput.classList.add('bg-washed-red', 'red')
  validationMessage.innerHTML = message
  validationMessage.classList.remove('dn')
}

function hideParameterValidationMessage(fieldName) {
  const validationContext = document.querySelector(`[data-validation="${fieldName}"]`)
  if (!validationContext) { return }

  const validationInput = validationContext.querySelector(`[data-validation-input="${fieldName}"]`)
  const validationMessage = validationContext.querySelector(`[data-validation-message="${fieldName}"]`)
  if (!validationInput || !validationMessage) { return }

  validationInput.classList.remove('bg-washed-red', 'red')
  validationMessage.innerHTML = ''
  validationMessage.classList.add('dn')
}

function skippedRegexResult() {
  return Promise.resolve({ status: 'skipped' })
}

function regexResult(parameter, value, options = {}) {
  if (!parameter) { return skippedRegexResult() }
  if (!parameter.validate_input_format) { return skippedRegexResult() }
  if (!parameter.regex_pattern) { return skippedRegexResult() }
  if (patternTooLong(parameter)) { return skippedRegexResult() }
  if (!value || value.length < 1) { return skippedRegexResult() }
  if (valueTooLong(value)) { return skippedRegexResult() }

  const { matchFn = regexMatchWithTimeout, ...matchOptions } = options

  return matchFn(parameter.regex_pattern, value, matchOptions)
}
