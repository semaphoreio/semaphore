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
      console.log("PARAMS")
      console.log(params)
      pollmanList.updateOptionsAndFetch(container, params);

      const currentUrl = new URL(window.location.href);
      
      const queryParams = ['page_token', 'direction', 'date_from', 'date_to'];
      
      queryParams.forEach(queryParam => {
        currentUrl.searchParams.set(queryParam, params[queryParam] || '');
      });
      
      console.log("current url")
      console.log(currentUrl.toString())
      
      window.history.pushState({}, '', currentUrl.toString());
    }
      
    this.pagination.onUpdate(updatePollman);
    this.initDateFilterButtons(pollmanList);
  },
  
  initDateFilterButtons: function(pollmanList) {
    console.log("TEST")
    const filterBtn = document.getElementById('filter-workflows-btn');
    const clearBtn = document.getElementById('clear-filter-btn');
    
    if (filterBtn) {
      filterBtn.addEventListener('click', () => {
        const container = document.querySelector('.pollman-container');
        const dateFrom = document.getElementById('date_from')?.value;
        const dateTo = document.getElementById('date_to')?.value;
        
        // Build params object with pagination and date filters
        const params = {};
        
        // Get pagination params if they exist
        const pageToken = container.getAttribute('data-poll-param-page_token');
        const direction = container.getAttribute('data-poll-param-direction');
        
        if (pageToken) {
          params.page_token = pageToken;
        }
        
        if (direction) {
          params.direction = direction;
        }
        
        // Add date filter params if they exist
        if (dateFrom) {
          params.date_from = dateFrom;
          container.setAttribute('data-poll-param-date_from', dateFrom);
        } else {
          container.removeAttribute('data-poll-param-date_from');
        }
        
        if (dateTo) {
          params.date_to = dateTo;
          container.setAttribute('data-poll-param-date_to', dateTo);
        } else {
          container.removeAttribute('data-poll-param-date_to');
        }
        
        // Manually trigger the update with all params
        this.pagination.update(container, params);
      });
    }
    
    if (clearBtn) {
      clearBtn.addEventListener('click', () => {
        // Clear date inputs
        const dateFrom = document.getElementById('date_from');
        const dateTo = document.getElementById('date_to');
        
        if (dateFrom) dateFrom.value = '';
        if (dateTo) dateTo.value = '';
        
        // Clear date params from pollman container
        const container = document.querySelector('.pollman-container');
        container.removeAttribute('data-poll-param-date_from');
        container.removeAttribute('data-poll-param-date_to');
        
        // Trigger update with pagination params only
        const params = {};
        
        // Get pagination params if they exist
        const pageToken = container.getAttribute('data-poll-param-page_token');
        const direction = container.getAttribute('data-poll-param-direction');
        
        if (pageToken) {
          params.page_token = pageToken;
        }
        
        if (direction) {
          params.direction = direction;
        }
        
        this.pagination.update(container, params);
      });
    }
    
    // Initialize date inputs from URL params if they exist
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
    
    // Set initial pollman data attributes
    if ((dateFrom || dateTo) && document.querySelector('.pollman-container')) {
      const container = document.querySelector('.pollman-container');
      
      if (dateFrom) {
        container.setAttribute('data-poll-param-date_from', dateFrom);
      }
      
      if (dateTo) {
        container.setAttribute('data-poll-param-date_to', dateTo);
      }
      
      // If we have date filters on page load, ensure they're applied immediately
      // by triggering the first poll with the date parameters
      if (this.pagination && (dateFrom || dateTo)) {
        const currentParams = {};
        
        // Get pagination params if they exist
        const pageToken = container.getAttribute('data-poll-param-page_token');
        const direction = container.getAttribute('data-poll-param-direction');
        
        if (pageToken) {
          currentParams.page_token = pageToken;
        }
        
        if (direction) {
          currentParams.direction = direction;
        }
        
        if (dateFrom) {
          currentParams.date_from = dateFrom;
        }
        
        if (dateTo) {
          currentParams.date_to = dateTo;
        }
        
        // Wait for DOM to be ready
        setTimeout(() => {
          // The pollman container might not be fully initialized yet, so we'll check again
          const pollmanContainer = document.querySelector('.pollman-container');
          if (pollmanContainer) {
            this.pagination.update(pollmanContainer, currentParams);
          }
        }, 500);
      }
    }
  }
}
