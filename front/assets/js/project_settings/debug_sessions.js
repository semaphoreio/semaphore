import $ from "jquery";

export var DebugSessionsSettings = {
  init: function() {
    this.settings = $("#debug-session-settings");
    this.registerDisableDebugSessionHandler();
  },

  registerDisableDebugSessionHandler() {
    if($('input[name="project[custom_permissions]"][checked]').val() == "false") {
      $("#debug-session-options").hide();
    } else {
      $("#debug-session-options").show();
    }

    this.settings.on("click", "[data-action=disableDebugSessions]", () => {
      $("#debug-session-options").hide();
    })

    this.settings.on("click", "[data-action=useCustomSettings]", () => {
      $("#debug-session-options").show();
    })
  }
}
