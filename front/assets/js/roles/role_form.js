import _ from "lodash"

export class RoleForm {
  static init() {
    return new RoleForm()
  }

  constructor() {
    this.handleSearchInput()
  }

  handleSearchInput(debounceTimeout = 500) {
    const searchBars = document.querySelectorAll('input[data-action="filterPermissions"]')
    if (!searchBars || searchBars.length === 0) { return; }

    searchBars.forEach((textInput) => {
      textInput.addEventListener('input', _.debounce((event) => {
        const queryString = event.target.value ? event.target.value.trim() : ''
        this.showAndHidePermissions(queryString)
      }, debounceTimeout))
    })
  }

  showAndHidePermissions(queryString) {
    const permissionElements = document.querySelectorAll('div[data-element="permission"]')
    if (!permissionElements || permissionElements.length === 0) { return; }

    permissionElements.forEach((permissionElement) => {
      const permissionName = permissionElement.getAttribute('data-label')
      if (permissionName.includes(queryString.toLowerCase())) {
        permissionElement.classList.remove('dn')
      } else {
        permissionElement.classList.add('dn')
      }
    })
  }
}
