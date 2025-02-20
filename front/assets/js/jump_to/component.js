import $ from "jquery"
import _ from "lodash";

import { Template } from "./template"

export class Component {
  constructor(jumpTo, outputDivSelector, inputSelector, model) {
    this.state = {
      selectedIndex: null,
      items: null
    };

    this.jumpTo = jumpTo
    this.model = model

    this.outputDivSelector = outputDivSelector
    this.inputSelector = inputSelector

    this.handleFilterInput()
    this.handleKeyDownOnInput()
    this.handleStarItemClick()
    this.handleUnStarItemClick()
  }

  filtering() {
    return this.model.filtering
  }

  getGroups() {
    return _.groupBy(this.getResults(), (item) => item.kind)
  }

  getResults() {
    return _.sortBy(this.model.results, function(r) { return r.name.toLocaleLowerCase(); });
  }

  getSelectedIndex() {
    return this.model.selectedIndex
  }

  goToSelection() {
    let nodes = document.querySelectorAll(this.outputDivSelector)
    let node = nodes[nodes.length - 1]
    const selectedResultElement = node.querySelector(`[aria-selected="true"] a`)

    window.location = selectedResultElement.href
  }

  onlySelectionChanged() {
    return (this.state.selectedIndex != this.model.selectedIndex) && (this.state.items == this.model.items)
  }

  update() {
    if (this.onlySelectionChanged(this.model)) {
      this.changeSelection();
    } else {
      this.render();
    }

    // Make sure selected result isn't scrolled out of view
    let nodes = document.querySelectorAll(this.outputDivSelector)
    let node = nodes[nodes.length - 1]
    const selectedResultElement = node.querySelector(`[aria-selected="true"]`)
    if (selectedResultElement) {
      selectedResultElement.scrollIntoView({block: "nearest"});
    }

    this.state = {
      selectedIndex: this.model.selectedIndex,
      items: this.model.items
    }
  }

  render() {
    let nodes = document.querySelectorAll(this.outputDivSelector)
    let node = nodes[nodes.length - 1]
    $(node).html(Template.render(this))
  }

  changeSelection() {
    let nodes = document.querySelectorAll(this.outputDivSelector)
    let node = nodes[nodes.length - 1]

    let currentlySelected = node.querySelector(`li[aria-selected="true"]`).removeAttribute("aria-selected")
    node.querySelectorAll(`li`)[this.model.selectedIndex].setAttribute("aria-selected", true)
  }

  handleFilterInput() {
    this.jumpTo.on("input", this.inputSelector, (e) => {
      this.model.changeFilter(e.target.value)
    });
  }

  handleKeyDownOnInput() {
    this.jumpTo.on("keydown", this.inputSelector, (e) => {
      const { key } = event

      switch (key) {
        case 'Up': // IE/Edge
        case 'ArrowUp':
          event.preventDefault()
          this.model.moveSelection(-1)
          break
        case 'Down': // IE/Edge
        case 'ArrowDown': {
          event.preventDefault()
          this.model.moveSelection(+1)
          break
        }
        case 'Enter': {
          this.goToSelection()
          break
        }
        case 'Esc': // IE/Edge
        case 'Escape': {
          e.target.value = ""
          this.model.changeFilter("")
          this.jumpTo.hideTippy()
          break
        }
        default:
          return
      }
    });
  }

  handleUnStarItemClick() {
    this.jumpTo.on("click", ".projects-menu-unstar", (e) => {
      this.model.removeStar(e.target.dataset.favoriteType, e.target.dataset.favoriteId)
    });
  }

  handleStarItemClick() {
    this.jumpTo.on("click", ".projects-menu-star", (e) => {
      this.model.addStar(e.target.dataset.favoriteType, e.target.dataset.favoriteId)
    });
  }
}
