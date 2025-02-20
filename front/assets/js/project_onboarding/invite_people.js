import $ from "jquery"

export var InviteProjectPeople = {
  init: function() {
    $("body").on("click", "input[type=checkbox]", function() {
      if($("input:checked").length > 0) {
        $("#invite-people-submit").removeAttr("disabled");
      } else {
        $("#invite-people-submit").attr("disabled", "");
      }
    });

    $("body").on("click", "#invite-people-submit", function(event) {
      let submitButton = $(event.currentTarget);
      let invitation_list = $("input[type=checkbox]:checked").map(function() {
        return {
          username: $(this).data("username"),
          invite_email: $(this).data("email"),
          uid: String($(this).data("uuid")),
          provider: String($(this).data("provider"))
        }
      }).get();

      let req = $.ajax({
        url: submitButton.data("action-url"),
        data: JSON.stringify({invitation_list: invitation_list}),
        contentType: "application/json",
        type: "POST",
        beforeSend: function(xhr) {
          xhr.setRequestHeader("X-CSRF-Token", $("meta[name='csrf-token']").attr("content"));
          submitButton.addClass("btn-working");
        }
      });

      req.done(function() {
        window.location = window.InjectedDataByBackend.nextPageHref;
      });

      req.fail(function() {
        submitButton.removeClass("btn-working");
        Notice.error("Something went wrong");
      });
    });

    $("body").on("keyup", "input[type=email]", function(event) {
      let emailInput = $(event.currentTarget);
      let uuid = emailInput.data("uuid");
      let checkbox = $(`input[type=checkbox][data-uuid=${uuid}]`);
      let value = event.currentTarget.value.trim();
      checkbox.attr("data-email", value);
    });

    $("body").on("click", "#select-all-link", function() {
      $("input[type=checkbox]").prop('checked', true);
      $("#invite-people-submit").removeAttr("disabled");
    });

    $("body").on("click", "#select-none-link", function() {
      $("input[type=checkbox]").prop('checked', false);
      $("#invite-people-submit").attr("disabled", "");
    });
  }
}
