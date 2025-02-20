import $ from "jquery";

import { Star } from "../star"
import { QueryList } from "../query_list"
import { Props } from "../props"

import { ChooseSelect } from "./components/choose_select"

export class Project {
  static init() {
    let config = {
      filters: InjectedDataByBackend.FilterOptions
    }
    return new Project(config)
  }

  constructor(config) {
    this.config = config

    let divs = {
      chooseSelect: "#chooseSelect",
    }

    this.components = {
      select: new ChooseSelect(this, divs.chooseSelect, this.config.filters),
      star: new Star(),
      jumpTo: new QueryList(".project-jumpto", {
        dataUrl: InjectedDataByBackend.BranchUrl,
        handleSubmit: function (result) {
          if (result.html_url) { window.location = result.html_url }
        },
        mapResults: function (results, selectedIndex) {
          return results.map((result, index) => {
            const props = new Props(index, selectedIndex, "autocomplete")

            let icon;
            switch (result.type) {
              case 'branch':
                icon = `${InjectedDataByBackend.AssetsPath}/images/icn-branch.svg`
                break;
              case 'pull-request':
                icon = `${InjectedDataByBackend.AssetsPath}/images/icn-pullrequest.svg`
                break;
              case 'tag':
                icon = `${InjectedDataByBackend.AssetsPath}/images/icn-tag.svg`
                break;
            }

            return `<a href="${result.html_url}" ${props}>
                  <img width=16 class="mr2 db-l" src="${icon}">
                  <span>${escapeHtml(result.display_name)}</span>
              </a>`
          }).join("")
        }
      })
    }
  }

  on(event, selector, callback) {
    console.log(`Registering event: '${event}', target: '${selector}'`)

    $("body").on(event, selector, (e) => {
      console.log(`Event for '${event}' on ${selector} started`)
      let result = callback(e)
      console.log(`Event for '${event}' on ${selector} finished`)

      return result
    })
  }
}
