import { AgentPoller } from "./poller"
import $ from "jquery";

export class SelfHostedAgents {
  static waitForAgents(opts) {
    let poller = new AgentPoller(
      opts.firstPageUrl,
      opts.agentTypeName,
      opts.nextPageUrl,
      opts.latestAgentVersion,
      opts.canManage
    )

    poller.poll()
  }

  static handleTokenReveal() {
    const token = $(".self-hosted-agent-access-token")
    const revealButton = $(".self-hosted-agent-access-token-reveal")

    revealButton.on('click', () => {
      revealButton.hide();
      token.show();
    })
  }

  static handleNameReleaseSwitch() {
    const update = function(value) {
      if (value == "false") {
        $("#name-release-options").show();
      } else {
        $("#name-release-options").hide();
        $(`input[name="self_hosted_agent[agent_name_release_after]"]`).val(0);
      }
    }

    const checked = $('input[name="self_hosted_agent[agent_name_release]"]:checked')
    update(checked.val())

    $("#self_hosted_agent_settings").on("click", "[data-action=nameReleaseSwitch]", (e) => {
      update($(e.currentTarget).val())
    })
  }

  static handleNameAssignmentSwitch() {
    const update = function(value) {
      if (value == "ASSIGNMENT_ORIGIN_AWS_STS") {
        $("#name-assignment-options__ASSIGNMENT_ORIGIN_AWS_STS").show();
      } else {
        $("#name-assignment-options__ASSIGNMENT_ORIGIN_AWS_STS").hide();
        $(`input[name="self_hosted_agent[aws_account]"]`).val('');
        $(`input[name="self_hosted_agent[aws_role_patterns]"]`).val('');
      }
    }

    const checked = $('input[name="self_hosted_agent[agent_name_assignment_origin]"]:checked')
    update(checked.val())

    $("#self_hosted_agent_settings").on("click", "[data-action=nameAssignmentSwitch]", (e) => {
      update(e.currentTarget.value)
    })
  }

  static handleNameFieldChange() {
    const nameInput = $('#self-hosted-agent-name');
    const suffix = $('#self-hosted-agent-name-suffix');
    const typeName = $('#self-hosted-agent-type-name');
    const registerButton = $('#register-self-hosted-agent');

    const updateName = function() {
      const name = suffix.val().trim().replace(/[^a-zA-Z0-9_]/g, "-")
      nameInput.val(`s1-${name}`);
      typeName.text(`s1-${name}`);
    }

    suffix.on('input', updateName)
    updateName()

    suffix.on('keyup', function() {
      if (suffix.val() != '') {
        registerButton.prop('disabled', false);
      } else {
        registerButton.prop('disabled', true);
      }
    });
  }

  static handleInstructionsChange() {
    const inactiveClasses = 'b--black-10 hover-b--dark-gray';

    $('.self-hosted-instructions-button').on('click', function() {
      let id = $(this).attr("data-for");
      let instructions = $(`#${id}`);
      let clickedButton = $(this);
      instructions.show();
      instructions.siblings().hide();
      clickedButton.removeClass(inactiveClasses);
      clickedButton.siblings().addClass(inactiveClasses);
    });
  }
}
