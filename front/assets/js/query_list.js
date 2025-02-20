require('domurl')

import AutocompleteCore from '@trevoreyre/autocomplete'
import debounce from "./debounce"
import Url from "domurl"

export class QueryList {
  constructor(root, config) {
    this.config = config
    this.expanded = false
    this.loading = null
    this.position = {}
    this.resetPosition = true

    this.root = typeof root === 'string' ? document.querySelector(root) : root
    this.hiddenInput = this.root.querySelector('input[type=hidden]')
    this.input = this.root.querySelector('input[type=text]')
    this.resultList = this.root.querySelector('.jumpto-results')
    this.placeholderList = this.root.querySelector('.jumpto-placeholder')

    const core = new AutocompleteCore({
      search: input => {
        if (input.length < 1 && this.config.data) { return this.config.data }

        var url = new Url(this.config.dataUrl)
        url.query.name_contains = input

        return new Promise(resolve => {
          fetch(url.toString())
          .then(response => response.json())
          .then(data => { resolve(data) })
        })
      },
      autoSelect: true,
      setValue: this.setValue.bind(this),
      setAttribute: this.setAttribute.bind(this),
      onUpdate: this.handleUpdate.bind(this),
      onShow: this.handleShow.bind(this),
      onHide: this.handleHide.bind(this),
      onSubmit: this.config.handleSubmit
    })

    core.handleInput = debounce(core.handleInput, 300)

    this.core = core

    this.initialize()
  }

  initialize() {
    this.input.addEventListener('input', this.core.handleInput)
    this.input.addEventListener('keydown', this.handleKeyDown.bind(this))
    this.input.addEventListener('focus', this.core.handleFocus)
    this.input.addEventListener('blur', this.core.handleBlur)
    this.resultList.addEventListener(
      'mousedown',
      this.core.handleResultMouseDown
    )
    this.resultList.addEventListener('click', this.core.handleResultClick)

    this.updateStyle()
  }

  handleKeyDown(event) {
    const { key } = event

    // if input is inside form we are preventing from submiting the form.
    if (key == "Enter" && this.expanded) {
      event.preventDefault();
    }

    this.core.handleKeyDown(event)
  }

  setAttribute(attribute, value) {
    this.input.setAttribute(attribute, value)
  }

  setValue(result) {
    this.hiddenInput.value = result ? this.getResultHiddenValue(result) : ''
    this.input.value = result ? this.getResultValue(result) : ''
  }

  getResultHiddenValue(result) {
    return result.id
  }

  getResultValue(result) {
    return result.display_name
  }

  handleUpdate(results, selectedIndex) {
    this.resultList.innerHTML = this.config.mapResults(results, selectedIndex)

    this.core.checkSelectedResultVisible(this.resultList)
  }

  handleShow() {
    this.expanded = true
    this.updateStyle()
  }

  handleHide() {
    this.expanded = false
    this.resetPosition = true
    this.updateStyle()
  }

  updateStyle() {
    this.root.dataset.expanded = this.expanded
    this.root.dataset.loading = this.loading
    this.root.dataset.position = this.position

    this.resultList.style.visibility = this.expanded ? 'visible' : 'hidden'
    if(this.placeholderList) {
      this.placeholderList.style.display = this.expanded ? 'none' : 'block'
    }
  }
}
