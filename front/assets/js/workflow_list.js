import $ from "jquery";

import { TokenPagination } from "./pollman_list/token_pagination"
import { PollmanList } from "./pollman_list/list"

export var WorkflowList = {
  init: function() {
    if(this.initiated === true) { return; }

    this.initiated = true

    this.pagination = new TokenPagination("#workflow-lists")

    let pollmanList = new PollmanList;

    let updatePollman = function(container, params) {
      pollmanList.updateOptionsAndFetch(container, params);
    }

    this.pagination.onUpdate(updatePollman);
  }
}
