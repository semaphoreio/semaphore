import $ from "jquery";

import { TokenPagination } from "./pollman_list/token_pagination"
import { PollmanList } from "./pollman_list/list"

export var WorkflowList = {
  initiated: false,
  pagination: null,
  pollmanList: null,
  container: null,

  init: function() {
    if(this.initiated === true) { return; }

    this.initiated = true
    this.pagination = new TokenPagination("#workflow-lists")
    let pollmanList = new PollmanList;

    let updatePollman = function(container, params) {
      const queryParams = ['page_token', 'direction', 'date_from', 'date_to'];
      pollmanList.updateOptionsAndFetch(container, params);

      const currentUrl = new URL(window.location.href);
      
      queryParams.forEach(queryParam => {
        currentUrl.searchParams.set(queryParam, params[queryParam] || '');
      });
      
      window.history.pushState({}, '', currentUrl.toString());
    }
      
    this.pagination.onUpdate(updatePollman);
    this.initFilterButtons(updatePollman, pollmanList);
    this.initializeDateFilterValues();
  },
  
  initFilterButtons: function(updatePollman, pollmanList) {
    const filterBtn = document.getElementById('filter-workflows-btn');
    const clearBtn = document.getElementById('clear-filter-btn');
    const container = document.querySelector('.pollman-container');
    
    if (filterBtn) {
      filterBtn.addEventListener('click', () => {
        pollmanList.clearAllOptions(container)
        const dateFrom = document.getElementById('date_from')?.value;
        const dateTo = document.getElementById('date_to')?.value;
        
        const params = {};
               
        if (dateFrom) {
          params.date_from = dateFrom;
        }
        
        if (dateTo) {
          params.date_to = dateTo;
        }
        
        updatePollman(container, params)
      });
    }
    
    if (clearBtn) {
      clearBtn.addEventListener('click', () => {
        pollmanList.clearAllOptions(container)
        const dateFrom = document.getElementById('date_from');
        const dateTo = document.getElementById('date_to');
        
        if (dateFrom) dateFrom.value = '';
        if (dateTo) dateTo.value = '';
        
        updatePollman(container, {});
      });
    }
  },

  initializeDateFilterValues: function() {
    const urlParams = new URLSearchParams(window.location.search);
    const dateFrom = urlParams.get('date_from');
    const dateTo = urlParams.get('date_to');
    
    const dateFromInput = document.getElementById('date_from');
    const dateToInput = document.getElementById('date_to');
    
    if (dateFrom && dateFromInput) {
      dateFromInput.value = dateFrom;
    }
    
    if (dateTo && dateToInput) {
      dateToInput.value = dateTo;
    }
  }
}
