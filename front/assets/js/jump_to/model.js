import $ from "jquery"
import _ from "lodash";

import { Notice } from "../notice"

export class Model {
  constructor(starred, projects, dashboards) {
    this.items = _.concat(this.injectType(starred, "starred"), this.injectType(projects, "project"), this.injectType(dashboards, "dashboard"))

    this.filter = ""
    this.filtering = false
    this.selectedIndex = 0
    this.results = this.items
  }

  injectType(items, type) {
    return items.map(item => {
      item.kind = type

      return item
    })
  }

  addStar(kind, id) {
    let req = this.updateStar("star", id, kind)
    this.transferItem(kind, id, "starred")
    this.changeFilter(this.filter)

    req.fail(() => {
      this.transferItem(kind, id, kind)
      this.changeFilter(this.filter)

      Notice.error(`Error while adding ${kind} to favorites, please try again later.`)
    })
  }

  removeStar(kind, id) {
    let req = this.updateStar("unstar", id, kind)
    this.transferItem(kind, id, kind)
    this.selectedIndex = 0
    this.changeFilter(this.filter)

    req.fail(() => {
      this.transferItem(kind, id, "starred")
      this.changeFilter(this.filter)

      Notice.error(`Error while removing ${kind} from favorites, please try again later.`)
    })
  }

  transferItem(kind, id, to) {
    _.remove(this.items, (item) => item.id == id && item.type == kind).forEach(item => {
      item.kind = to
      this.items = this.items.concat([item])
    })
  }

  changeFilter(filter) {
    this.filter = filter
    this.filtering = filter.length > 0
    this.selectedIndex = 0
    this.results = this.items.filter(item => {
      return item.name.toLowerCase().includes(filter.toLowerCase())
    })

    this.afterUpdate()
  }

  moveSelection(direction) {
    const resultsCount = this.results.length
    const selectedIndex = this.selectedIndex + direction

    if(selectedIndex < 0) {
      this.selectedIndex = 0
    } else if (selectedIndex > resultsCount - 1) {
      this.selectedIndex = resultsCount - 1
    } else {
      this.selectedIndex = selectedIndex
    }

    this.afterUpdate()
  }

  onUpdate(callback) {
    this.callback = callback
  }

  afterUpdate() {
    if(this.callback !== null && this.callback !== undefined) {
      this.callback()
    }
  }

  updateStar(action, id, kind) {
    return $.ajax({
      url: `/sidebar/${action}`,
      data: { favorite_id: id, kind: kind },
      type: "POST",
      beforeSend: function(xhr) {
        xhr.setRequestHeader("X-CSRF-Token", $("meta[name='csrf-token']").attr("content"));
      }
    });
  }
}
