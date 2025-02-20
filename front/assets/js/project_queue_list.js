import $ from "jquery";

import { Pagination } from "./pollman_list/pagination"
import { PollmanList } from "./pollman_list/list"

export var ProjectQueueList = {
  init: function() {
    if(this.initiated === true) { return; }

    this.initiated = true

    this.pagination = new Pagination($("#project-queue-list .pagination"));

    let pollmanList = new PollmanList("#project-queue-list .pollman-container");

    let updatePollman = function(params) {
      pollmanList.updateOptionsAndFetch(params);
    }

    this.pagination.onUpdate(updatePollman);

    this.redraw()
  },
  redraw() {
    // redraw only if we inject data in a view
    if (typeof InjectedDataByBackend !== 'undefined') {
      this.pagination.render(InjectedDataByBackend.PaginationOptions);
    }
  }
}
