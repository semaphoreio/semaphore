import $ from "jquery";

export var GithubCollaborators = {

  init: function() {
    GithubCollaborators.registerRefresh();
    GithubCollaborators.registerSelectMetaHandlers();
    GithubCollaborators.registerSelectHandlers();
    GithubCollaborators.refreshSubmitButtonCount();
  },

  load(){
    let path = window.InjectedDataByBackend.GithubCollaborators.LoadPath;

    $.get(path, function(data){
      $("#loaded-gh-collaborators").html(data);
      GithubCollaborators.refreshSubmitButtonCount();
    });
  },

  reload() {
    window.Notice.notice("Collaborator list will be refreshed shortly. Depending on your team size, and number of projects it may take a couple of minutes.")

    $("[gh-collaborator]").each(function() {
      $(this).remove();
    });
    GithubCollaborators.load();
    console.log("trying to remove class")
    $("[refresh-gh-collaborators]").removeClass("btn-working");
  },

  selectAllOpacity() {
    $("[faded]").each(function() {
      $(this).removeClass("o-50");
    });
    document.querySelectorAll("[type='email']").forEach(element => {
      element.disabled = false;
    });
  },

  unselectAllOpacity() {
    $("[faded]").each(function() {
      $(this).addClass("o-50");
    });
    document.querySelectorAll("[type='email']").forEach(element => {
      element.disabled = true;
    });
  },

  registerRefresh() {
    $("body").on("click", "[refresh-gh-collaborators]", function(event) {
      let target = $(event.currentTarget)
      target.addClass("btn-working");

      let req = $.ajax({
        url: window.InjectedDataByBackend.GithubCollaborators.RefreshPath,
        type: "POST",
        beforeSend: function(xhr) {
          xhr.setRequestHeader("X-CSRF-Token", $("meta[name='csrf-token']").attr("content"));
        }
      });

      req.done(function() {
        console.log("Successfully triggered repository collaborators refresh");

        setTimeout(GithubCollaborators.reload, 2000);
      })
    });
  },

  refreshSubmitButtonCount() {
    let button = $("#people-potential-members-submit")
    let selected = $("#people-potential-members-list input:checkbox:checked").length

    button.text("Add selected ("+selected+")");
    button.prop("disabled", selected == 0);
  },

  registerSelectMetaHandlers() {
    let people = "#people-potential-members-list input:checkbox"

    $("body").on("click", "[data-action=selectAll]", () => {
      $(people).prop("checked", true);
      GithubCollaborators.selectAllOpacity();
      GithubCollaborators.refreshSubmitButtonCount();
    })

     $("body").on("click", "[data-action=selectNone]", () => {
       $(people).prop("checked", false);
       GithubCollaborators.unselectAllOpacity();
       GithubCollaborators.refreshSubmitButtonCount();
     })
  },

  registerSelectHandlers() {
    let people = "#people-potential-members-list input:checkbox"

    $("body").on("change", people, (event) => {
      let target = $(event.currentTarget)

      target.closest("[gh-collaborator]").find("[type='email']")
        .attr("disabled", !target.prop("checked"));

      target.parent().toggleClass("o-50");
      GithubCollaborators.refreshSubmitButtonCount();
    })
  }
}
