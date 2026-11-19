import $ from "jquery"
import _ from "lodash";

import { Notice } from "../notice"

export class Model {
  constructor(starred, projects, dashboards, current) {
    this.items = _.concat(this.injectType(starred, "starred"), this.injectType(projects, "project"), this.injectType(dashboards, "dashboard"))

    this.current = current || {}
    this.filter = ""
    this.filtering = false
    this.results = this.items
    this.selectedIndex = this.defaultSelectedIndex()
  }

  injectType(items, type) {
    return items.map(item => {
      item.kind = type

      return item
    })
  }

  //
  // The results in the order the template lays them out: a flat alphabetical
  // list while filtering, otherwise grouped starred → projects → dashboards.
  //
  // selectedIndex is an offset into this list, so anything that computes or
  // resolves a selection has to go through here.
  //
  orderedResults() {
    let sorted = _.sortBy(this.results, (r) => r.name.toLocaleLowerCase())

    if(this.filtering) {
      return sorted
    }

    let groups = _.groupBy(sorted, (item) => item.kind)

    return _.concat(groups.starred || [], groups.project || [], groups.dashboard || [])
  }

  //
  // Start the selection on the item the user is currently looking at, so that
  // the highlight matches the page instead of always pointing at the first
  // starred item. Falls back to the top of the list off a project page.
  //
  defaultSelectedIndex() {
    let index = this.orderedResults().findIndex((item) => this.isCurrent(item))

    return index === -1 ? 0 : index
  }

  isCurrent(item) {
    if(this.current.id) {
      return item.id === this.current.id
    }

    let path = this.current.path

    return !!path && (path === item.path || path.startsWith(`${item.path}/`))
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
    this.results = this.items.filter(item => {
      return item.name.toLowerCase().includes(filter.toLowerCase())
    })
    this.selectedIndex = this.filtering ? 0 : this.defaultSelectedIndex()

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
