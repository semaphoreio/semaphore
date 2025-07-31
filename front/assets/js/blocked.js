import $ from "jquery"
import { QueryList } from "./query_list"
import { Props } from "./props"

export var Blocked = {
  init: function() {
    this.options = {
      working: false,
      checkWorkflow: null
    }

    Blocked.registerBuildClick()
    Blocked.registerHookFilter()
  },

  registerBuildClick() {
    $("#hooks").on("click", "[data-action=buildBlocked]", function(event) {
      event.preventDefault();

      if (this.options.working) { return false; }

      Blocked.buildBlocked(event.currentTarget)

    }.bind(this));
  },

  registerHookFilter() {
    new QueryList(".project-jumpto", {
      dataUrl: InjectedDataByBackend.QueryList.HookUrl,
      data: InjectedDataByBackend.QueryList.Data,
      handleSubmit: function(result) {
        Blocked.submitBuildRequest(result.html_url, result.display_name)
      },
      mapResults: function(results, selectedIndex) {
        return results.map((result, index) => {
          const props = new Props(index, selectedIndex, "autocomplete", "link db bb b--lighter-gray pv2 hide-child hover-bg-row-highlight")

          return `<a href="${result.html_url}" data-branch-name="${escapeHtml(result.display_name)}" data-action="buildBlocked" ${props}>
            <div class="flex pv1">
              <div class="flex-shrink-0 pr3">
                <img src="${result.icon}" alt="branch" class="v-mid">
              </div>
              <div class="flex-auto">
                <div class="flex-ns items-start justify-between">
                  <div>
                    <h3 class="f4 dark-gray mb0">${escapeHtml(result.display_name)}</h3>
                  </div>
                  <div class="child dn db-ns flex-shrink-0 btn btn-primary">
                    →
                  </div>
                </div>
              </div>
            </div>
          </a>`
        }).join("")
      }
    })
  },

  buildBlocked: function(target) {
    $(target).find(".btn").addClass("btn-working");

    var url = $(target)[0].href
    var branch = $(target).closest("a").data("branch-name")

    Blocked.submitBuildRequest(url, branch)

    //$(target).find(".btn").removeClass("btn-working");
  },

  submitBuildRequest(url, branch) {
    this.options.working = true;

    let csrf = $("meta[name='csrf-token']").attr("content")
    var body = new FormData()
    body.append("branch", branch)
    body.append("_csrf_token", csrf)

    console.log(`Build Blocked ${url} ${body}`)

    fetch(url, {
      method: 'POST',
      body: body
    })
    .then((res) => {
      var contentType = res.headers.get("content-type");

      if(contentType && contentType.includes("application/json")) {
        return res.json();
      } else {
        throw new Error(res.statusText);
      }
    })
    .then((res) => {
      if(res.error) {
        Notice.notice(res.error);
        throw new Error(res.error);
      } else {
        return res;
      }
    })
    .then((data) => {
      Notice.notice(data.message);

      this.afterBuildHandler(data.branch, data.workflow_id, data.check_url);
    })
    .catch(function(reason) {
      console.log(reason)

      this.options.working = false
    }.bind(this))
  },

  afterBuildHandler(branch, workflowId, checkUrl) {
    var query = [`branch=${encodeURIComponent(branch)}`, `workflow_id=${encodeURIComponent(workflowId)}`].join("&")
    var url   = checkUrl + "?" + query

    console.log(`Checking workflows ${url}`)

    fetch(url)
    .then((res) => {
      var contentType = res.headers.get("content-type");

      if(contentType && contentType.includes("application/json")) {
        return res.json();
      } else {
        throw new Error(res.statusText);
      }
    })
    .then((data) => {
      if(data.workflow_url == null) {
        setTimeout(this.afterBuildHandler.bind(this, branch, workflowId, checkUrl), 1000)
      } else {
        window.location = data.workflow_url;
        this.options.working = false
      }
    })
    .catch(
      (reason) => { console.log(reason); }
    )
  },

  parseJson: function(response) {
    if (this.isJsonResponse(response)) {
      return response.json();
    } else {
      throw new Error(response.statusText);
    }
  },
}
