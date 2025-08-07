import $ from "jquery";
import { QueryList } from "../query_list"
import { Props } from "../props"

export var GeneralSettings = {
  init: function() {
    this.settings = $("#build-settings");

    this.registerIntegrationTypeSwitchHandler();
    this.registerBuildPauseHandler();
    this.registerBranchSwitchHandler();
    this.registerBranchWhitelistSwitchHandler();
    this.registerTagSwitchHandler();
    this.registerTagWhitelistSwitchHandler();
    this.registerForkedPRSwitchHandler();
    this.registerDraftPRSwitchHandler();
    this.registerSecretsSwitchHandler();
    this.registerContributorsSwitchHandler();
    this.registerVisibilitySwitchHandler();
    this.registerOwnerFilter();
  },

  registerOwnerFilter() {
    if($(".jumpto-results").length > 0) {
      new QueryList(".project-jumpto", {
        dataUrl: InjectedDataByBackend.OwnerUrl,
        mapResults: function(results, selectedIndex) {
          return results.map((result, index) => {
            const props = new Props(index, selectedIndex, "autocomplete")

            return `<span ${props}>
    <img src="${result.avatar_url}" class="ba b--black-50 br-100 mr2" width="32">
          <span>${escapeHtml(result.display_name)}</span>
          </span>`
          }).join("")
        }
      })
    }
  },

  registerIntegrationTypeSwitchHandler() {
    $("body").on("submit", "#switch-to-github-app", function(e) {
      var button = e.target.querySelector("button");
      button.classList.remove("btn-green");
      button.classList.add("btn-working");
      button.innerText = "Checking for access"
    });
  },

  registerBuildPauseHandler() {
    if($('input[name="project[run]"][checked]').val() == "true") {
      $("#build-options").show();
    } else {
      $("#build-options").hide();
    }

    this.settings.on("click", "[data-action=pauseBuild]", () => {
      $("#build-options").hide();
    })

    this.settings.on("click", "[data-action=resumeBuild]", () => {
      $("#build-options").show();
    })
  },

  registerBranchSwitchHandler() {
    if($('input[name="project[build_branches]"][checked]').length == 0) {
      $("#branch-options").hide();
    } else {
      $("#branch-options").show();
    }

    this.settings.on("click", "[data-action=branchSwitch]", (e) => {
      if($(e.currentTarget).prop("checked")) {
        $("#branch-options").show();
      } else {
        $("#branch-options").hide();
      }
    })
  },

  registerBranchWhitelistSwitchHandler() {
    if($('input[name="project[whitelist_branches]"][checked]').val() == "true") {
      $("#whitelisted-branches").show();
    } else {
      $("#whitelisted-branches").hide();
    }

    this.settings.on("click", "[data-action=runAllBranches]", (e) => {
      $("#whitelisted-branches").hide();
    })

    this.settings.on("click", "[data-action=whitelistBranches]", (e) => {
      $("#whitelisted-branches").show();
    })
  },

  registerTagSwitchHandler() {
    if($('input[name="project[build_tags]"][checked]').length == 0) {
      $("#tag-options").hide();
    } else {
      $("#tag-options").show();
    }

    this.settings.on("click", "[data-action=tagSwitch]", (e) => {
      if($(e.currentTarget).prop("checked")) {
        $("#tag-options").show();
      } else {
        $("#tag-options").hide();
      }
    })
  },

  registerTagWhitelistSwitchHandler() {
    if($('input[name="project[whitelist_tags]"][checked]').val() == "true") {
      $("#whitelisted-tags").show();
    } else {
      $("#whitelisted-tags").hide();
    }

    this.settings.on("click", "[data-action=runAllTags]", (e) => {
      $("#whitelisted-tags").hide();
    })

    this.settings.on("click", "[data-action=whitelistTags]", (e) => {
      $("#whitelisted-tags").show();
    })
  },

  registerForkedPRSwitchHandler() {
    if($('input[name="project[build_forked_prs]"][checked]').length == 0) {
      $("#pull-request-options").hide();
    } else {
      $("#pull-request-options").show();
    }

    this.settings.on("click", "[data-action=forkedPRSwitch]", (e) => {
      if($(e.currentTarget).prop("checked")) {
        $("#pull-request-options").show();
      } else {
        $("#pull-request-options").hide();
      }
    })
  },

  registerDraftPRSwitchHandler() {
    if($('input[name="project[build_prs]"][checked]').length == 0) {
      $("#draft-pull-request-options").hide();
    } else {
      $("#draft-pull-request-options").show();
    }

    this.settings.on("click", "[data-action=draftPRSwitch]", (e) => {
      if($(e.currentTarget).prop("checked")) {
        $("#draft-pull-request-options").show();
      } else {
        $("#draft-pull-request-options").hide();
      }
    })
  },

  registerSecretsSwitchHandler() {
    if($('input[name="project[expose_secrets]"][checked]').val() == "true") {
      $("#exposed-secrets").show();
    } else {
      $("#exposed-secrets").hide();
    }

    this.settings.on("click", "[data-action=disableSecrets]", (e) => {
      $("#exposed-secrets").hide();
    })

    this.settings.on("click", "[data-action=exposeSecrets]", (e) => {
      $("#exposed-secrets").show();
    })
  },

  registerContributorsSwitchHandler() {
    if($('input[name="project[filter_contributors]"][checked]').val() == "true") {
      $("#allowed-contributors").show();
    } else {
      $("#allowed-contributors").hide();
    }

    this.settings.on("click", "[data-action=openContributors]", (e) => {
      $("#allowed-contributors").hide();
    })

    this.settings.on("click", "[data-action=filterContributors]", (e) => {
      $("#allowed-contributors").show();
    })
  },

  registerVisibilitySwitchHandler() {
    if($('#project-visibility').val() == "true") {
      $("#project-public").show();
      $("#project-private").hide();
    } else {
      $("#project-public").hide();
      $("#project-private").show();
    }
  }
}
