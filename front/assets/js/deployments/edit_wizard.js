export default {
  init(components) {
    return new EditDeploymentTargetWizard(components)
  }
}

const allSections = ['basics', 'credentials', 'subjects', 'objects'];

class EditDeploymentTargetWizard {
  constructor(components) {
    this.components = components

    this.handleEditButton()
  }

  handleEditButton() {
    document
      .getElementById('dtw-edit-button')
      .addEventListener('click', (event) => {
        if (this.validateForm()) {
          document.forms['target'].submit()
        }
      })
  }

  validateForm() {
    allSections.forEach(sectionName => this.components[sectionName].renderValidations())
    return allSections.every(sectionName => this.components[sectionName].isValid())
  }
}
