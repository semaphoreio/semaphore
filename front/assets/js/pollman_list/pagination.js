import $ from "jquery";

export class Pagination {
  constructor(container) {
    this.container = container;
    this.options = {page: 1};

    this.handleClicks()
  }

  handleClicks() {
    $(this.container).on("click", "[data-action=LoadPage]", (e) => {
      let token = $(e.target).data("token")
      let container = $(e.target).parents('.pollman-container')[0]

      this.callback(container, {page_token: token})

      e.preventDefault();
      e.stopPropagation();
    })
  }

  onUpdate(callback) {
    this.callback = callback
  }
}
