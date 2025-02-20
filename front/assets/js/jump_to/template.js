export class Template {
  static render(component) {
    return `
      ${this.shortcut(component.filtering())}
      <ul class="list pl0 mb0">
      ${this.render(component)}
      </ul>
    `
  }

  static shortcut(filtering) {
    if(filtering) {
      return ""
    } else {
      return `<p class="f7 mb0 gray">Keyboard shortcut: "/"</p>`
    }
  }

  static render(component) {
    if(component.filtering()) {
      return this.renderResults(component)
    } else {
      return this.renderGroups(component)
    }
  }

  static renderResults(component) {
    var selectedIndex = component.getSelectedIndex()
    var results = component.getResults()

    return this.elements(results, 0, selectedIndex)
  }

  static renderGroups(component) {
    var index = 0
    var groups = component.getGroups()
    var selectedIndex = component.getSelectedIndex()
    var html = ""

    if(groups.starred) {
      html += `
      ${this.header(component.filtering(), groups.starred, "Starred")}
      ${this.elements(groups.starred, index, selectedIndex)}
      `

      index = index + groups.starred.length
    }

    if(groups.project) {
      html += `
      ${this.header(component.filtering(), groups.project, "Projects")}
      ${this.elements(groups.project, index, selectedIndex)}
      `

      index = index + groups.project.length
    }

    if(groups.dashboard) {
      html += `
      ${this.header(component.filtering(), groups.dashboard, "Dashboards")}
      ${this.elements(groups.dashboard, index, selectedIndex)}
      `
    }

    return html
  }


  static header(filtering, el, title) {
    if(filtering || el.length == 0) {
      return ""
    } else {
      return `
      <div class="f5 b mt2 mb1 pt2 bt b--black-10">${title}</div>
      `
    }
  }

  static elements(el, index, selectedIndex) {
    return el.map(
      (element, idx) => {
        var startClass = "projects-menu-star"
        if(element.kind == "starred") {
          startClass = "projects-menu-unstar"
        }
        var attr = ""
        if((idx + index) == selectedIndex) {
          attr = attr + ` aria-selected="true"`
        }

        return `
        <li ${attr}>
        <a href="${element.path}">${element.name}</a>
        <div data-favorite-type="${element.type}" data-favorite-id="${element.id}" class="${startClass}"></div>
        </li>
        `
      }
    ).join('');
  }
}
