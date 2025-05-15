import { TokenPagination } from "./pollman_list/token_pagination"
import { PollmanList } from "./pollman_list/list"

export var WorkflowList = {
  initiated: false,
  pagination: null,
  pollmanList: null,
  container: null,
  queryParams: ['page_token', 'direction', 'date_from', 'date_to'],

  init: function() {
    if(this.initiated === true) { return; }

    this.initiated = true
    this.pagination = new TokenPagination("#workflow-lists")
    let pollmanList = new PollmanList;

    let updatePollman = function(container, params) {
      const currentUrl = new URL(window.location.href);
      const mergedParams = {};
      
      WorkflowList.queryParams.forEach(queryParam => {
        const currentValue = currentUrl.searchParams.get(queryParam);
        if (currentValue) {
          mergedParams[queryParam] = currentValue;
        }
      });
      
      Object.keys(params).forEach(key => {
        mergedParams[key] = params[key];
      });
      
      pollmanList.updateOptionsAndFetch(container, mergedParams);
      
      WorkflowList.queryParams.forEach(queryParam => {
        const paramValue = mergedParams[queryParam];
        if (paramValue && paramValue !== '') {
          currentUrl.searchParams.set(queryParam, paramValue);
        } else {
          currentUrl.searchParams.delete(queryParam);
        }
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
    
    if (filterBtn) {
      filterBtn.addEventListener('click', () => {
        const dateFrom = document.getElementById('date_from')?.value;
        const dateTo = document.getElementById('date_to')?.value;
        
        if (dateFrom && dateTo) {
          const fromDate = new Date(dateFrom);
          const toDate = new Date(dateTo);
          
          if (fromDate > toDate) {
            alert('Start date must be before end date');
            return;
          }
        }
        
        let params = {'page_token': '', 'direction': ''};
        params.date_from = dateFrom;
        params.date_to = dateTo;
        
        const container = document.querySelector('.pollman-container');
        updatePollman(container, params);
      });
    }
    
    if (clearBtn) {
      clearBtn.addEventListener('click', () => {
        const dateFrom = document.getElementById('date_from');
        const dateTo = document.getElementById('date_to');
        
        if (dateFrom) dateFrom.value = '';
        if (dateTo) dateTo.value = '';

        const container = document.querySelector('.pollman-container');
        
        const emptyParams = {};
        WorkflowList.queryParams.forEach(param => {
          emptyParams[param] = '';
        });

        updatePollman(container, emptyParams);
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
