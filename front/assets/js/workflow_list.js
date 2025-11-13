import { TokenPagination } from "./pollman_list/token_pagination"
import { PollmanList } from "./pollman_list/list"
import debounce from "./debounce"

export var WorkflowList = {
  initiated: false,
  pagination: null,
  pollmanList: null,
  container: null,
  queryParams: ['page_token', 'direction', 'date_from', 'date_to', 'author', 'listing', 'requester'],

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
    this.initFilterButtons(updatePollman);
    this.initializeDateFilterValues();
  },
  
  initFilterButtons: function(updatePollman) {
    const dateFromInput = document.getElementById('date_from');
    const dateToInput = document.getElementById('date_to');
    const authorInput = document.getElementById('author');
    
    
    const applyFilters = () => {
      const dateFrom = dateFromInput?.value;
      const dateTo = dateToInput?.value;
      const author = authorInput?.value;
      
      if (dateFrom && dateTo) {
        const filterErrorMessage = document.getElementById('filter_error_message');
        const fromDate = new Date(dateFrom);
        const toDate = new Date(dateTo);
        
        if (fromDate > toDate && filterErrorMessage) {
          filterErrorMessage.hidden = false;
          return;
        } else if (filterErrorMessage) {
          filterErrorMessage.hidden = true;
        }
      }
      
      let params = {'page_token': '', 'direction': ''};
      params.date_from = dateFrom;
      params.date_to = dateTo;
      params.author = author;
      
      const container = document.querySelector('.pollman-container');
      updatePollman(container, params);
    };
    
    if (authorInput) {
      authorInput.addEventListener('input', debounce(applyFilters, 300, false));
    }
    if (dateFromInput) {
      dateFromInput.addEventListener('change', applyFilters);
    }
    if (dateToInput) {
      dateToInput.addEventListener('change', applyFilters);
    }
  },

  initializeDateFilterValues: function() {
    const urlParams = new URLSearchParams(window.location.search);
    const dateFrom = urlParams.get('date_from');
    const dateTo = urlParams.get('date_to');
    const author = urlParams.get('author');
    
    const dateFromInput = document.getElementById('date_from');
    const dateToInput = document.getElementById('date_to');
    const authorInput = document.getElementById('author');
    
    if (dateFrom && dateFromInput) {
      dateFromInput.value = dateFrom;
    }
    
    if (dateTo && dateToInput) {
      dateToInput.value = dateTo;
    }
    
    if (author && authorInput) {
      authorInput.value = author;
    }
  }
}
