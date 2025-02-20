export default {
  init(components) {
    return new CreateDeploymentTargetWizard(components)
  }
}

const allSections = ['basics', 'credentials', 'subjects', 'objects'];

class CreateDeploymentTargetWizard {
  constructor(components) {
    this.components = components
    this.currentSection = null
    this.finalized = false

    this.handleNextButtons()
    this.handleCreateButton()
    this.moveToNextSection()
  }

  handleNextButtons() {
    allSections.forEach((sectionName) => {
      findSection(sectionName)
        .querySelector('[data-action="dtw-next-section"]')
        .addEventListener('click', () => {
          if (this.validateForm()) {
            this.moveToNextSection()
          }
        })
    })
  }

  handleCreateButton() {
    document
      .getElementById('dtw-create-button')
      .addEventListener('click', () => {
        if (this.finalized && this.validateForm()) {
          document.forms['target'].submit()
        }
      })
  }

  validateForm() {
    const sectionIndex = this.currentSection ? allSections.indexOf(this.currentSection) : -1
    const viewedSections = allSections.slice(0, sectionIndex + 1)

    if (viewedSections) {
      viewedSections
        .forEach(sectionName => this.components[sectionName].renderValidations())

      return viewedSections
        .every(sectionName => this.components[sectionName].isValid())
    }
  }

  moveToNextSection() {
    const sectionIndex = this.currentSection ? allSections.indexOf(this.currentSection) : -1
    const nextSection = allSections.at(sectionIndex + 1)

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
  const doneSection = document.querySelector('#dtw-section-done')
  const submitButton = document.getElementById('dtw-create-button')

  hideAllSections()
  markSectionAsViewed(doneSection)

  submitButton.classList.remove('disabled')
  submitButton.removeAttribute('disabled')
}

function findSection(sectionName) {
  return document.getElementById(`dtw-section-${sectionName}`)
}

function hideAllSections() {
  document
    .querySelectorAll('[data-element="dtw-section"]')
    .forEach((section) => section.removeAttribute('open'))
}

function markSectionAsViewed(section) {
  section.querySelector('summary').removeAttribute('data-state')
  section.querySelector('[data-element="dtw-bubble"]').classList.add('bg-dark-indigo')
  section.querySelector('[data-element="dtw-header"]').classList.remove('light-gray')
}
