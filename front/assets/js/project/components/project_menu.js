import $ from "jquery"

export class ProjectMenu {
  constructor() {
    this.handleClickOnDots()
  }

  handleClickOnDots() {
    $.on("click", "#projectMenuDots", function() {
      $("#projectMenu").toggle();
    });
  }
}
