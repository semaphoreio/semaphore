import $ from "jquery"
import { Cookie } from "../cookie"

export var ForkExplanation = {
  init: function() {
    ForkExplanation.handleHide();
    ForkExplanation.handleClose();
  },

  handleHide: function() {
    $("body").on("click", "[data-action='hideForkExplanation']", () => {
      document.getElementById("semaphore-concepts").removeAttribute("open");
      window.location = "#semaphore-concepts";

      return false;
    });
  },

  handleClose: function() {
    $("body").on("click", "[data-action='closeForkExplanation']", () => {
      document.getElementById("forkExplanation").remove();

      Cookie.setPermanent("close_fork_explanation", true, false)

      return false;
    });
  }
}
