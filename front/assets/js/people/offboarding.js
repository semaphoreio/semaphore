import $ from "jquery"

import { Http } from "./../http"

export var Offboarding = {
  init: function() {
    this.el = $(".offboarding")
    this.registerOffboardingActions()
  },

  registerOffboardingActions() {
    $(this.el).on("click", "[data-action=transfer-project]", (e) => {
      let element = $(e.currentTarget)

      element.parent().hide()
      element.parent().parent().find("[data-offboarding=are-you-sure-transfer]").show()
    })

    $(this.el).on("click", "[data-action=remove-project]", (e) => {
      let element = $(e.currentTarget)

      element.parent().hide()
      element.parent().parent().find("[data-offboarding=are-you-sure-remove]").show()
    })

    $(this.el).on("click", "[data-action=offboarding-nevermind]", (e) => {
      let element = $(e.currentTarget)

      element.parent().hide()
      element.parent().parent().find("[data-offboarding=offboard]").show()
    })

    $(this.el).on("click", "[data-action=offboarding-transfer]", (e) => {
      let element = $(e.currentTarget)

      let endpoint = element.attr("data-endpoint")

      element.parent().hide()
      element.parent().parent().find("[data-offboarding=transferring]").show()

      Http.post(endpoint, {}, (response) => {
        response.text().then(function(text) {
          element.parent().parent().replaceWith(text);

          Offboarding.checkRemoveButton()
        });
      })
    })


    $(this.el).on("click", "[data-action=offboarding-remove]", (e) => {
      let element = $(e.currentTarget)

      let endpoint = element.attr("data-endpoint")

      element.parent().hide()
      element.parent().parent().find("[data-offboarding=removing]").show()

      Http.delete(endpoint, {}, (response) => {
        response.text().then(function(text) {
          element.parent().parent().replaceWith(text);

          Offboarding.checkRemoveButton()
        });
      })
    })

    $(this.el).on("click", "[data-action=remove-user]", (e) => {
      let element = $(e.currentTarget)

      if(confirm(element.data('confirmMsg'))) {
        element.prop('disabled', true);
        element.addClass('btn-working');
        element.text("Removing");
      } else {
        e.stopPropagation();
      }
    });
  },

  checkRemoveButton() {
    const pending = $(this.el).find("[data-offboarding=pending]");
    const failed = $(this.el).find("[data-offboarding=failed]");

    if(pending.length == 0 && failed.length == 0) {
      const button = $(this.el).find("[data-action=remove-user]")
      button.prop('disabled', false)
    }
  }
}
