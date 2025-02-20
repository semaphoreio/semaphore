import $ from "jquery";
import { QueryList } from "../query_list"
import { Props } from "../props"

export var BadgeSettings = {
  init: function() {
    BadgeSettings.registerBranchFilter();
    BadgeSettings.registerBadgeChanges();
    BadgeSettings.setCodeText();
    // BadgeSettings.renderSemaphoreStyle();
    // BadgeSettings.renderShieldsStyle();
  },

  registerBranchFilter() {
    new QueryList(".project-jumpto", {
      dataUrl: InjectedDataByBackend.BranchUrl,
      mapResults: function(results, selectedIndex) {
        return results.map((result, index) => {
          const props = new Props(index, selectedIndex, "autocomplete")

          return `<span href="${result.html_url}" ${props}>
          <span>${escapeHtml(result.display_name)}</span>
          </span>`
        }).join("")
      }
    })
  },

  registerBadgeChanges() {
    $("body").on("change keyup", "[data='badge']", (event) => {
      BadgeSettings.setCodeText();
    });
  },

  setCodeText() {
    let codeText
    let selectedFormat = $("input[name='badge-format']:checked").val();

    switch(selectedFormat) {
      case "markdown":
        codeText = BadgeSettings.constructMarkdownText()
        break;
      case "svg":
        codeText = BadgeSettings.constructSvgText()
        break;
      case "html":
        codeText = BadgeSettings.constructHtmlText()
        break;
      default:
        codeText = BadgeSettings.constructMarkdownText()
    }

    $("#badge-code").val(codeText)
  },

  constructMarkdownText() {
    let badgeUrl = BadgeSettings.buildBranchBadgeUrl();
    let projectUrl = BadgeSettings.buildProjectUrl();

    let text = "[![Build Status](" + badgeUrl + ")](" + projectUrl + ")";

    return text
  },

  constructSvgText() {
    return BadgeSettings.buildBranchBadgeUrl()
  },

  constructHtmlText() {
    let badgeUrl = BadgeSettings.buildBranchBadgeUrl();
    let branchUrl = BadgeSettings.buildBranchBadgeUrl();

    let text = "<a href='" + branchUrl + "'> <img src='" + badgeUrl + "' alt='Build Status'></a>"

    return text
  },

  buildProjectUrl() {
    let orgDomain = window.InjectedDataByBackend.OrganizationDomain;
    let project = window.InjectedDataByBackend.ProjectName;

    return orgDomain + "/projects/" + project
  },

  buildProjectBadgeUrl(badgeStyle) {
    let orgDomain = window.InjectedDataByBackend.OrganizationDomain;
    let project = window.InjectedDataByBackend.ProjectName

    let isProjectPublic = window.InjectedDataByBackend.Public;

    let queryParams = {};
    let baseUrl = orgDomain + "/badges/" + project + ".svg"

    if (badgeStyle === "shields") {
      queryParams.style = "shields"
    }

    if (isProjectPublic === "false") {
      queryParams.key = window.InjectedDataByBackend.ProjectId
    }

    if ($.isEmptyObject(queryParams)) {
      return baseUrl
    } else {
      let qs = new URLSearchParams(queryParams).toString();
      return baseUrl + "?" + qs
    }
  },

  buildBranchBadgeUrl() {
    let orgDomain = window.InjectedDataByBackend.OrganizationDomain;
    let project = window.InjectedDataByBackend.ProjectName
    let branch = $("#badge-branch").val() || "master";

    let selectedBadgeStyle = $("input[name='badge-style']:checked").val();
    let isProjectPublic = window.InjectedDataByBackend.Public;

    let queryParams = {};
    let baseUrl = orgDomain + "/badges/" + project + "/branches/" + branch + ".svg"

    if (selectedBadgeStyle === "shields") {
      queryParams.style = "shields"
    }

    if (isProjectPublic === "false") {
      queryParams.key = window.InjectedDataByBackend.ProjectId
    }

    if ($.isEmptyObject(queryParams)) {
      return baseUrl
    } else {
      let qs = new URLSearchParams(queryParams).toString();
      return baseUrl + "?" + qs
    }
  },

  // renderSemaphoreStyle() {
  //   let projectUrl = BadgeSettings.buildProjectUrl();
  //   let badgeUrl = BadgeSettings.buildProjectBadgeUrl("semaphore");

  //   let data = `
  //   Semaphore Custom <a href='${projectUrl}'> <img src='${badgeUrl}' alt='Build Status' class="v-mid ml1"></a>
  //   `

  //   $("[badge='semaphore']").html(data)
  // },

  // renderShieldsStyle() {
  //   let projectUrl = BadgeSettings.buildProjectUrl();
  //   let badgeUrl = BadgeSettings.buildProjectBadgeUrl("shields");

  //   let data = `
  //   Shields <a href='${projectUrl}'> <img src='${badgeUrl}' alt='Build Status' class="v-mid ml1"></a>
  //   `

  //   $("[badge='shields']").html(data)
  // }
}
