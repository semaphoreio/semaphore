require('domurl')

import { MemoryCookie } from "../../memory_cookie"
import Url from "domurl"

export class ChooseSelect {
  constructor(project, selectSelector, filters) {
    this.project = project
    this.filters = filters
    this.selectSelector = selectSelector

    this.handleSelect()
  }

  handleSelect() {
    let selector = `${this.selectSelector} select`

    this.project.on("change", selector, (e) => {
      let value = e.target.value;
      let key  = e.target.getAttribute("data-key")

      MemoryCookie.set('project' + key.charAt(0).toUpperCase() + key.slice(1), value)

      var u  = new Url;
      u.query[key] = value;

      window.location.href = u.toString()
    })
  }
}
