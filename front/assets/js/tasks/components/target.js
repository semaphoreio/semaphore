export default {
  init(params) {
    return new TargetComponent(params.branch || params.reference_name, params.pipeline_file, params.reference_type || 'branch')
  }
}

import { Validator, Rule } from './validation'

class TargetComponent {
  constructor(referenceName, pipelineFile, referenceType = 'branch') {
    this.currentReferenceType = referenceType

    this.validators = {
      branch: new Validator('branch', referenceName, [
        new Rule((n) => n.length < 1, 'cannot be empty')
      ]),
      pipelineFile: new Validator('pipelineFile', pipelineFile, [
        new Rule((n) => n.length < 1, 'cannot be empty')
      ])
    }

    this.handleFieldChange('branch')
    this.handleFieldChange('pipelineFile')
    this.handleReferenceTypeChange()
    this.updateReferenceLabel()
    this.updatePlaceholder()
    this.updateReferenceTypeText()
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
    const element = document.querySelector(`[data-validation-input="${fieldName}"]`)
    if (element) {
      element.addEventListener('input', (event) => {
        this.changeFieldValue(fieldName, event.target.value)
      })
    }
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
    this.updatePlaceholder()
    this.updateReferenceTypeText()
  }

  updateReferenceLabel() {
    const labelElement = document.querySelector('[data-reference-label]')
    if (labelElement) {
      switch (this.currentReferenceType) {
        case 'tag':
          labelElement.textContent = 'Tag'
          break
        case 'pr':
          labelElement.textContent = 'Pull Request'
          break
        default:
          labelElement.textContent = 'Branch'
      }
    }
  }

  updateReferenceTypeText() {
    const textElement = document.querySelector('[data-reference-type-text]')
    if (textElement) {
      switch (this.currentReferenceType) {
        case 'tag':
          textElement.textContent = 'tag'
          break
        case 'pr':
          textElement.textContent = 'pull request'
          break
        default:
          textElement.textContent = 'branch'
      }
    }
  }

  updatePlaceholder() {
    const inputElement = document.querySelector('[data-validation-input="branch"]')
    if (inputElement) {
      switch (this.currentReferenceType) {
        case 'tag':
          inputElement.placeholder = 'e.g. v1.0.0'
          break
        case 'pr':
          inputElement.placeholder = 'e.g. 123'
          break
        default:
          inputElement.placeholder = 'e.g. master'
      }
    }
  }
}
