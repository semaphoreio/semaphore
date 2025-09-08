export default {
  init(params) {
    return new SubjectsComponent()
  }
}


import TomSelect from 'tom-select'

class SubjectsComponent {
  constructor() {
    this.rolesTomSelect = newTomSelect('roles-select')
    this.peopleTomSelect = newTomSelect('people-select')

    this.handleUserAccessChanged()
    this.toggleUserAccessDetails()
  }

  toggleUserAccessDetails() {
    const someUserAccessRadioButton = document.getElementById('target_user_access_some')

    if (someUserAccessRadioButton) {
      const someUserAccessEnabled = someUserAccessRadioButton.checked
      const userAccessDetails = document.querySelector('[data-component="user-access-details"]')

      if (someUserAccessEnabled) {
        userAccessDetails.classList.remove('dn')
      } else {
        userAccessDetails.classList.add('dn')
      }
    }
  }

  handleUserAccessChanged() {
    document
      .querySelectorAll('[name="target[user_access]"]')
      .forEach((element) => element.addEventListener('input', () => {
        this.toggleUserAccessDetails()
      }))
  }

  isValid() { return true }
  renderValidations() { }
}

function newTomSelect(componentName) {
  const component = document.querySelector(`[data-component="${componentName}"]`)

  if (component) {
    return new TomSelect(`[data-component="${componentName}"]`, {
      searchField: [{ field: 'text' }],
      sortField: { field: 'text' },
      plugins: ['no_backspace_delete', 'remove_button'],

      onChange: function () { this.control_input.value = '' },
      render: { item: renderItem },
    })
  }

  return component
}

function renderItem(data, escape) {
  return `
    <div class="item" data-ts-item="">
      <span>${escape(data.text)}</span>
    </div>
  `
}
