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
      .addEventListener('click', async () => {
        if (await this.validateForm()) {
          document.forms[0].submit()
        }
      })
  }

  async validateForm() {
    this.sectionNames.forEach(sectionName => this.components[sectionName].renderValidations())

    const syncValid = this.sectionNames.every(sectionName => this.components[sectionName].isValid())
    if (!syncValid) { return false }

    await Promise.all(
      this.sectionNames.map(sectionName => {
        const component = this.components[sectionName]
        return component.renderAsyncValidations ? component.renderAsyncValidations() : Promise.resolve()
      })
    )

    return this.sectionNames.every(sectionName => this.components[sectionName].isValid())
  }
}
