import { QueryList } from "../query_list"
import { Props } from "../props"
import _ from "lodash"

import pikaday from 'pikaday';

export default {
  init(params) {
    return new HistoryPage(params)
  }
}

class HistoryPage {
  constructor(params) {
    this.baseUrl = params.baseUrl
    this.filters = params.filters

    this.jumpToBranch = jumpToBranch(this)
    this.calendarPikaday = datePicker(this)

    this.handleTextFilters()
    this.handleCustomDatePickers()
    this.tippy = dropdownTippy()
  }

  applyFiltersAndRefreshPage(newFilters) {
    this.applyFilters(newFilters)
    this.refreshPage()
  }

  applyFilters(newFilters) {
    this.filters = Object.assign(this.filters, newFilters)
  }

  refreshPage() {
    window.location.href = formUrl(this.baseUrl, this.filters);
  }

  handleTextFilters() {
    this.handleTextFilterApplied('git_ref_label')
    this.handleTextFilterApplied('git_ref_type')
    this.handleTextFilterApplied('triggered_by')
    this.handleTextFilterApplied('parameter1')
    this.handleTextFilterApplied('parameter2')
    this.handleTextFilterApplied('parameter3')
  }

  handleTextFilterApplied(filterKey, debounceTimeout = 1000) {
    const inputField = document.querySelector(`[data-key="${filterKey}"]`)
    if (!inputField) { return; }

    inputField.addEventListener('input', _.debounce((event) => {
      this.applyFiltersAndRefreshPage({ [filterKey]: event.target.value })
    }, debounceTimeout))
  }

  handleCustomDatePickers() {
    document
      .querySelectorAll('.x-dashboard-date-picker')
      .forEach((element) => element.addEventListener('click', () => {
        const timestamp = element.getAttribute('data-timestamp')
        this.applyFiltersAndRefreshPage({ direction: 'BEFORE', timestamp: timestamp })
      }))
  }
}

function formUrl(baseUrl, filters) {
  const esc = encodeURIComponent
  const query = Object.keys(filters)
    .map(k => esc(k) + '=' + esc(filters[k]))
    .join('&')

  return `${baseUrl}?${query}`
}

function datePicker(historyPage) {
  return new pikaday({
    field: document.querySelector('#pikadayInput'),
    minDate: new Date(2018, 10, 31), maxDate: new Date(),
    onSelect: (date) => historyPage.applyFiltersAndRefreshPage({
      direction: 'BEFORE', timestamp: dateToTimestamp(date)
    })
  })
}

function dateToTimestamp(date) {
  const dayInMilliseconds = 24 * 60 * 60 * 1000
  return (date.getTime() + dayInMilliseconds) + '000'
}

function dropdownTippy() {
  return tippy('.date-dropdown', {
    content: document.querySelector('#datePicker'),
    popperOptions: { strategy: 'fixed' },
    allowHTML: true,
    trigger: 'click',
    theme: 'dropdown',
    interactive: true,
    placement: 'bottom-end',
    duration: [100, 50],
    maxWidth: '640px',
    onShow: () => { },
    hideOnClick: 'toggle'
  })
}

function jumpToBranch(historyPage) {
  return new QueryList(".branch-jumpto", {
    dataUrl: InjectedDataByBackend.BranchUrl,
    handleSubmit: function (result) {
      if (result.display_name) {
        historyPage.applyFiltersAndRefreshPage({
          git_ref_type: result.type,
          git_ref_label: result.display_name
        })
      }
    },
    mapResults: function (results, selectedIndex) {
      return results.map((result, index) => {
        const props = new Props(index, selectedIndex, "autocomplete")
        let appliedFilters = {}

        appliedFilters = Object.assign(appliedFilters, historyPage.filters)
        appliedFilters = Object.assign(appliedFilters, {
          git_ref_type: result.type,
          git_ref_label: result.display_name
        })

        return `<a href=${formUrl(historyPage.baseUrl, appliedFilters)} ${props}>
                  <img width=16 class="mr2 db-l" src="${gitIcon(result.type)}">
                  <span>${escapeHtml(result.display_name)}</span>
                </a>`
      }).join("")
    }
  })
}

function gitIcon(type) {
  const prefix = `${InjectedDataByBackend.AssetsPath}/images`

  switch (type) {
    case 'branch':
      return `${prefix}/icn-branch.svg`
    case 'pull-request':
      return `${prefix}/icn-pullrequest.svg`
    case 'tag':
      return `${prefix}/icn-tag.svg`
  }
}
