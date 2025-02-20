import $ from "jquery"

export class Star {
  constructor() {
    this.handleStarClicks();
    this.handleUnstarClicks();
  }

  handleStarClicks() {
    let instance = this;
    $("body").on("click", "[starred=false]", function(event) {
      let target = $(event.currentTarget)
      let req = $.ajax({
        url: "/sidebar/star",
        data: {
          favorite_id: target.data("favorite-id"),
          kind: target.data("favorite-kind"),
        },
        type: "POST",
        beforeSend: function(xhr) {
          xhr.setRequestHeader("X-CSRF-Token", $("meta[name='csrf-token']").attr("content"));
        }
      });

      req.done(function() {
        target.addClass("yellow")
        target.removeClass("washed-gray")
        target.attr("starred", "true")
        instance.swapTippyContent(target);
      })
    });
  }

  handleUnstarClicks() {
    let instance = this;
    $("body").on("click", "[starred=true]", function(event) {
      let target = $(event.currentTarget)
      let req = $.ajax({
        url: "/sidebar/unstar",
        data: {
          favorite_id: target.data("favorite-id"),
          kind: target.data("favorite-kind"),
        },
        type: "POST",
        beforeSend: function(xhr) {
          xhr.setRequestHeader("X-CSRF-Token", $("meta[name='csrf-token']").attr("content"));
        }
      });

      req.done(function() {
        target.removeClass("yellow")
        target.addClass("washed-gray")
        target.attr("starred", "false")
        instance.swapTippyContent(target);
      })
    });
  }

  swapTippyContent(target) {
    let currentTippyContent = target.prop("_tippy").props.content;
    let newTippyContent = target.data("tippy-swap-content")
    target.prop("_tippy").setContent(newTippyContent)
    target.data("tippy-swap-content", currentTippyContent);
  }
}
