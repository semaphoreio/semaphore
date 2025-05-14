import $ from "jquery";

export class TokenPagination {
  constructor(container) {
    this.container = container;
    this.options = {token: "", direction: "next"};

    this.handleClicks()
  }

  handleClicks() {
    $(this.container).on("click", "[data-action=LoadPage]", (e) => {
      console.log("Handling onclinck")
      let direction = $(e.target).data("direction")
      let token = $(e.target).data("token")
      let container = $(e.target).parents('.pollman-container')[0]
      console.log(token)

      this.callback(container, {page_token: token, direction: direction})

      e.preventDefault();
      e.stopPropagation();
    })
  }

  onUpdate(callback) {
    this.callback = callback
  }
}
