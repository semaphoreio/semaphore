import $ from "jquery"

export var Notice = {
  init: function() {
    this.handleCloseClicks();
    this.setTimoutForNotice();
  },

  notice: function(msg) {
    $('#error').addClass('dn');
    $('#notice-message').text(msg);
    $('#notice').removeClass('dn');
    $('#notice').removeClass('disposable');
  },

  error: function(msg) {
    $("#notice").addClass('dn');
    $('#error-message').text(msg);
    $('#error').removeClass('dn');
  },

  setTimoutForNotice: function() {
    setTimeout(function() { $("#notice.disposable").addClass('dn'); }, 3000);
  },

  handleCloseClicks: function() {
    $("body").on("click", "#error-close", function(event) {
      $("#error").addClass('dn');

      return false; // prevent bubling the event
    })

    $("body").on("click", "#notice-close", function(event) {
      $("#notice").addClass('dn');

      return false; // prevent bubling the event
    })
  }
};
