export default {
  init(sectionNames, components) {
    return new CreateWizard(sectionNames, components)
  }
}

class CreateWizard {
  constructor(sectionNames, components) {
    this.sectionNames = sectionNames
    this.components = components
    this.currentSection = null
    this.finalized = false

    this.handleNextButtons()
    this.handleCreateButton()
    this.moveToNextSection()
  }

  handleNextButtons() {
    this.sectionNames.forEach((sectionName) => {
      findSection(sectionName)
        .querySelector('[data-action="wizard-next-section"]')
        .addEventListener('click', () => {
          if (this.validateForm()) {
            this.moveToNextSection()
          }
        })
    })
  }

  handleCreateButton() {
    document
      .getElementById('wizard-create-button')
      .addEventListener('click', () => {
        if (this.finalized && this.validateForm()) {
          document.forms[0].submit()
        }
      })
  }

  validateForm() {
    const sectionIndex = this.currentSection ? this.sectionNames.indexOf(this.currentSection) : -1
    const viewedSections = this.sectionNames.slice(0, sectionIndex + 1)

    if (viewedSections) {
      viewedSections
        .forEach(sectionName => this.components[sectionName].renderValidations())

      return viewedSections
        .every(sectionName => this.components[sectionName].isValid())
    }
  }

  moveToNextSection() {
    const sectionIndex = this.currentSection ? this.sectionNames.indexOf(this.currentSection) : -1
    const nextSection = this.sectionNames.at(sectionIndex + 1)

    if (nextSection) {
      if (this.currentSection) {
        hideNextButton(this.currentSection)
      }

      this.currentSection = nextSection
      revealSection(nextSection)
    } else {
      if (this.currentSection) {
        hideNextButton(this.currentSection)
      }

      this.finalized = true
      finalizeForm()
    }
  }
}

function hideNextButton(sectionName) {
  const section = findSection(sectionName)
  section.querySelector('[data-element="next-button"]').classList.add('dn')
}

function revealSection(sectionName) {
  const section = findSection(sectionName)

  hideAllSections()
  markSectionAsViewed(section)
  section.setAttribute('open', 'open')
}

function finalizeForm() {
  const doneSection = document.querySelector('#wizard-section-done')
  const submitButton = document.getElementById('wizard-create-button')

  hideAllSections()
  markSectionAsViewed(doneSection)

  submitButton.classList.remove('disabled')
  submitButton.removeAttribute('disabled')
}

function findSection(sectionName) {
  return document.getElementById(`wizard-section-${sectionName}`)
}

function hideAllSections() {
  document
    .querySelectorAll('[data-element="wizard-section"]')
    .forEach((section) => section.removeAttribute('open'))
}

function markSectionAsViewed(section) {
  section.querySelector('summary').removeAttribute('data-state')
  section.querySelector('[data-element="wizard-bubble"]').classList.add('bg-dark-indigo')
  section.querySelector('[data-element="wizard-header"]').classList.remove('light-gray')
}
