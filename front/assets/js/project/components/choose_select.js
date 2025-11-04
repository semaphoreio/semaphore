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

      if (key === "listing_requester") {
        this.updateListingRequester(value)
        return
      }

      MemoryCookie.set('project' + key.charAt(0).toUpperCase() + key.slice(1), value)

      var u  = new Url;
      u.query[key] = value;

      window.location.href = u.toString()
    })
  }

  updateListingRequester(value) {
    const selection = this.selectionFor(value)

    MemoryCookie.set('projectListing', selection.listing)
    MemoryCookie.set('projectRequester', selection.requester)

    const url = new Url
    url.query['listing'] = selection.listing
    url.query['requester'] = selection.requester
    delete url.query['page_token']
    delete url.query['direction']

    window.location.href = url.toString()
  }

  selectionFor(value) {
    switch (value) {
      case 'all_by_me':
        return { listing: 'all_pipelines', requester: 'true' }
      case 'latest_per_branch':
        return { listing: 'latest', requester: 'false' }
      default:
        return { listing: 'all_pipelines', requester: 'false' }
    }
  }
}
