export default {
  init(sectionNames, components) {
    return new EditWizard(sectionNames, components)
  }
}

class EditWizard {
  constructor(sectionNames, components) {
    this.sectionNames = sectionNames
    this.components = components

    this.handleEditButton()
  }

  handleEditButton() {
    document
      .getElementById('wizard-edit-button')
      .addEventListener('click', (event) => {
        if (this.validateForm()) {
          document.forms[0].submit()
        }
      })
  }

  validateForm() {
    this.sectionNames.forEach(sectionName => this.components[sectionName].renderValidations())
    return this.sectionNames.every(sectionName => this.components[sectionName].isValid())
  }
}
