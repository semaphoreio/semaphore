import _ from "lodash"

export default class SearchBar {
  static init(params) {
    return new SearchBar(params)
  }

  constructor(params) {
    this.baseUrl = params.baseUrl
    this.filters = { search: '' }

    this.handleSearchInput()
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

  handleSearchInput(debounceTimeout = 500) {
    const searchBars = document.querySelectorAll('input[data-action="filterTasks"]')
    if (!searchBars || searchBars.length === 0) { return; }

    searchBars.forEach((textInput) => {
      textInput.addEventListener('input', _.debounce((event) => {
        const queryString = event.target.value ? event.target.value.trim() : ''
        this.applyFiltersAndRefreshPage({ search: queryString })
      }, debounceTimeout))
    })
  }
}

function formUrl(baseUrl, filters) {
  const esc = encodeURIComponent
  const query = Object.keys(filters)
    .filter(k => filters[k])
    .map(k => esc(k) + '=' + esc(filters[k]))
    .join('&')

  return `${baseUrl}?${query}`
}
