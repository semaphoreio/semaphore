import { TokenPagination } from "./pollman_list/token_pagination"
import { PollmanList } from "./pollman_list/list"

export var WorkflowList = {
  init: function() {
    if(this.initiated === true) { return; }

    this.initiated = true

    this.pagination = new TokenPagination("#workflow-lists")

    let pollmanList = new PollmanList;
    const container = document.querySelector("#workflow-lists"); // Get the actual DOM element instead of just the selector string

    let updatePollman = function(container, params) {
      console.log("EXECUTING UPDATE POLLMAN", container, params)
      pollmanList.updateOptionsAndFetch(container, params);

      const currentUrl = new URL(window.location.href);
      currentUrl.searchParams.set('page_token', params.page_token);
      currentUrl.searchParams.set('direction', params.direction);
      window.history.pushState({}, '', currentUrl.toString());
    }

    window.addEventListener('popstate', function() {
      console.log("EXECUTING POPSTATE")
      const currentUrl = new URL(window.location.href);
      const pageToken = currentUrl.searchParams.get('page_token');
      const direction = currentUrl.searchParams.get('direction');
      console.log(container)
      console.log(currentUrl)
      console.log(pageToken)
      console.log(direction)
      console.log(currentUrl.searchParams)

      pollmanList.updateOptionsAndFetch(container, {
        page_token: pageToken,
        direction: direction
      });
    });

    this.pagination.onUpdate(updatePollman);
  }
}
