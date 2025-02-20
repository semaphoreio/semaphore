export default {
  init(params) {
    return new ObjectsComponent(params.branches, params.tags, params.branchMode, params.tagMode)
  }
}

const ObjectItem = class {
  constructor(json = {}) {
    this.matchMode = json.match_mode || '1'
    this.pattern = json.pattern || ''
  }

  isPatternValid() { return !!(this.pattern) }

  isValid() {
    return !this.validate().length
  }

  validate() {
    let validations = []

    if (!this.isPatternValid()) {
      validations.push({ field: 'pattern', message: 'must not be empty' })
    }

    return validations
  }
}

class ObjectsComponent {
  constructor(branches, tags, branchMode, tagMode) {
    this.branches = Array.from(branches).map(json => new ObjectItem(json));
    this.tags = Array.from(tags).map(json => new ObjectItem(json));

    this.branchMode = branchMode
    this.tagMode = tagMode

    this.renderItems(this.branchMode, this.branches, 'branch')
    this.renderItems(this.tagMode, this.tags, 'tag')
    this.handleAddItemButtons()
    this.handleModeChange()
  }

  isValid() {
    if (this.branchMode == 'whitelisted') {
      if (!this.branches.every(branch => branch.isValid())) {
        return false
      }
    }

    if (this.tagMode == 'whitelisted') {
      if (!this.tags.every(tag => tag.isValid())) {
        return false
      }
    }

    return true
  }

  renderValidations() {
    this.renderObjectItemValidations('branch')
    this.renderObjectItemValidations('tag')
  }

  addEmptyItem(itemType) {
    if (itemType === 'branch') {
      this.branches.push(new ObjectItem)
      this.renderItems(this.branchMode, this.branches, itemType)
    }
    if (itemType === 'tag') {
      this.tags.push(new ObjectItem)
      this.renderItems(this.tagMode, this.tags, itemType)
    }
  }

  changeMode(itemType, newMode) {
    if (itemType === 'branch') {
      this.branchMode = newMode
      if (this.branches.length === 0) {
        this.branches.push(new ObjectItem)
      }
      this.renderItems(this.branchMode, this.branches, itemType)
    }

    if (itemType === 'tag') {
      this.tagMode = newMode
      if (this.tags.length === 0) {
        this.tags.push(new ObjectItem)
      }
      this.renderItems(this.tagMode, this.tags, itemType)
    }
  }

  changeItem(itemType, index) {
    if (itemType === 'branch') { this.doChangeItem(this.branches, itemType, index) }
    if (itemType === 'tag') { this.doChangeItem(this.tags, itemType, index) }
  }

  doChangeItem(collection, itemType, index) {
    const prefix = `target_${collectionName(itemType)}_${index}`
    const patternElement = document.getElementById(`${prefix}_pattern`)
    const matchModeElement = document.getElementById(`${prefix}_match_mode`)

    Object.assign(collection[index], {
      pattern: patternElement.value,
      matchMode: matchModeElement.value
    })

    renderObjectItemValidation(itemType, collection[index], index)
  }

  deleteItem(itemType, index) {
    if (itemType === 'branch') {
      this.doDeleteItem(this.branches, index)
      if (this.branches.length === 0) {
        this.branches.push(new ObjectItem)
      }
      this.renderItems(this.branchMode, this.branches, itemType)
    }
    if (itemType === 'tag') {
      this.doDeleteItem(this.tags, index)
      if (this.tags.length === 0) {
        this.branches.push(new ObjectItem)
      }
      this.renderItems(this.tagMode, this.tags, itemType)
    }
  }

  doDeleteItem(collection, index) {
    collection.splice(index, 1)
  }

  renderItems(itemsMode, items, itemType, showValidations = false) {
    const itemsComponent = document.querySelector(`[data-component="${itemType}-details"]`)
    const itemsContainer = document.querySelector(`[data-component="${itemType}-items"]`)

    if (itemsMode !== 'whitelisted') {
      itemsComponent.classList.add('dn')
      return
    }

    itemsComponent.classList.remove('dn')
    itemsContainer.innerHTML = ''

    items.forEach(function (item, index) {
      const tagElementHTML = renderElement(itemType, item, index)
      itemsContainer.insertAdjacentHTML('beforeend', tagElementHTML)
      setMatchMode(itemType, item, index)
    })

    if (showValidations) {
      this.renderObjectItemValidations(itemType)
    }

    this.handleItemElements(itemType)
  }

  renderObjectItemValidations(itemType) {
    if (itemType === 'branch') {
      this.branches.forEach((branch, index) => renderObjectItemValidation(itemType, branch, index))
    }

    if (itemType === 'tag') {
      this.tags.forEach((tag, index) => renderObjectItemValidation(itemType, tag, index))
    }
  }

  handleAddItemButtons() {
    document
      .querySelector('[data-action="branch-item-add"]')
      .addEventListener('click', (event) => {
        event.preventDefault()
        this.addEmptyItem('branch')
      })

    document
      .querySelector('[data-action="tag-item-add"]')
      .addEventListener('click', (event) => {
        event.preventDefault()
        this.addEmptyItem('tag')
      })
  }

  handleModeChange() {
    document
      .querySelectorAll('[name="target[branch_mode]"]')
      .forEach((element) => element.addEventListener('input', (event) => {
        this.changeMode('branch', event.target.value)
      }))

    document
      .querySelectorAll('[name="target[tag_mode]"]')
      .forEach((element) => element.addEventListener('input', (event) => {
        this.changeMode('tag', event.target.value)
      }))

  }

  handleItemElements(itemType) {
    document
      .querySelector(`[data-component="${itemType}-items"]`)
      .querySelectorAll(`[data-component="${itemType}-item"]`)
      .forEach((tagItem) => {
        tagItem
          .querySelectorAll('[data-action="change-item"]')
          .forEach((element) => element.addEventListener('input', (event) => {
            const dataIndex = parseInt(event.target.getAttribute('data-index'))
            this.changeItem(itemType, dataIndex)
          }))

        tagItem
          .querySelector('[data-action="delete-item"]')
          .addEventListener('click', (event) => {
            event.preventDefault()

            const dataIndex = parseInt(event.target.getAttribute('data-index'))
            this.deleteItem(itemType, dataIndex)
          })
      })
  }
}

function setMatchMode(itemType, item, index) {
  const prefixId = `target_${collectionName(itemType)}_${index}`
  const element = document.getElementById(`${prefixId}_match_mode`)
  element.value = item.matchMode
}

function renderElement(itemType, item, index) {
  const prefixId = `target_${collectionName(itemType)}_${index}`
  const prefixName = `target[${collectionName(itemType)}][${index}]`

  return `
    <div id="${prefixId}" class="mb2" data-validation="${itemType}-item" data-index="${index}">
      <div class="flex items-center" data-component="${itemType}-item" data-index="${index}">
        <input id="${prefixId}_pattern" name="${prefixName}[pattern]" type="text" data-index="${index}"
              data-validation-input="pattern" data-action="change-item" value="${escapeHtml(item.pattern)}" class="form-control w5 mr2">
        <select id="${prefixId}_match_mode" name="${prefixName}[match_mode]" value="${item.matchMode}"
                data-index="${index}" data-action="change-item" class="form-control mr2">
          <option value="1">Exact match</option>
          <option value="2">Regex match</option>
        </select>
        <span data-action="delete-item" data-index="${index}" class="material-symbols-outlined gray pointer">
          delete
        </span>
      </div>
      <div class="f5 b mv1 red dn" data-validation-message="${itemType}-item"></div>
    </div>
  `
}


function renderObjectItemValidation(itemType, item, index) {
  const validationContext = document.querySelector(`[data-validation="${itemType}-item"][data-index="${index}"]`)
  if (!validationContext) {
    return;
  }

  const validationInputs = {
    pattern: validationContext.querySelector(`[data-validation-input="pattern"]`)
  }
  const validationMessage = validationContext.querySelector(`[data-validation-message="${itemType}-item"]`)
  let messages = []

  Object.values(validationInputs).forEach(input => {
    input.classList.remove('bg-washed-red', 'red')
  })

  item.validate().forEach(validation => {
    validationInputs[validation.field].classList.add('bg-washed-red', 'red')
    messages.push(`${validation.field} ${validation.message}`)
  })

  validationMessage.innerHTML = messages.join(', ')
  validationMessage.classList.remove('dn')
}

function collectionName(itemType) {
  if (itemType === 'branch') { return 'branches' }
  if (itemType === 'tag') { return 'tags' }
}
