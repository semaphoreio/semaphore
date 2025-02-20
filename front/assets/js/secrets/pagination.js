import $ from "jquery";

export class Pagination {
  constructor(options) {
    this.callback = options.onNewItems
    this.nextPageUrl = options.nextPageUrl
    this.loadMoreBtn = $('.pagination .load');
    this.loadMoreBtn.on('click', this.handleLoadMoreBtnClick.bind(this));
  }

  loadMore() {
    fetch(this.nextPageUrl)
      .then(r => r.json())
      .then(data => {
        this.callback(data.secrets)
        this.updateButtons(data.next_page_url)
      })
      .catch(err => this.handleError(err))
  }

  handleError(err) {
    console.error(err)
  }

  handleLoadMoreBtnClick() {
    this.loadMoreBtn.prop('disabled', true)
    this.loadMore()
  }

  updateButtons(nextPageUrl) {
    this.nextPageUrl = nextPageUrl

    // If there are no more items to load, hide the button.
    // Otherwise, we enable it again.
    if (this.nextPageUrl == "") {
      this.loadMoreBtn.hide();
    } else {
      this.loadMoreBtn.prop('disabled', false)
    }
  }
}
