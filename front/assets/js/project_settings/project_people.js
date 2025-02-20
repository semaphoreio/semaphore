import $ from "jquery";
import { QueryList } from "../query_list"
import { Props } from "../props"

export var ProjectPeople = {
    init: function() {
      this.registerOrgMembersFilter()
    },

    registerOrgMembersFilter() {
      if($(".jumpto-results").length > 0) {
        var list = new QueryList(".project-jumpto", {
          dataUrl: InjectedDataByBackend.OrgMembersUrl,
          mapResults: function(results, selectedIndex) {
            return results.map((result, index) => {
              const props = new Props(index, selectedIndex, "autocomplete")
              return `<span ${props}>
            <span>${escapeHtml(result.name)}</span>
            </span>`
            }).join("")
          }
        })

        list.getResultHiddenValue = function(result) {return result.id}
        list.getResultValue = function(result) {return result.name}
      }
    }
}
