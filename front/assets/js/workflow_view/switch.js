import $ from "jquery"

import { TriggerEvent } from "./trigger_event"
import { Pollman } from "../pollman"
import { TargetParams } from "./target_params"

const escapeSelector = (value) => {
  const normalizedValue = String(value ?? "");

  if ($.escapeSelector) {
    return $.escapeSelector(normalizedValue);
  }

  if (typeof CSS !== "undefined" && CSS.escape) {
    return CSS.escape(normalizedValue);
  }

  return normalizedValue.replace(/(["\\])/g, "\\$1");
}
const switchScopeSelector = (switchId) => `[switch="${escapeSelector(switchId)}"]`
const promotionTargetSelector = (promotionTarget) => `[data-promotion-target="${escapeSelector(promotionTarget)}"]`
const promotionScopedSelector = (switchId, promotionTarget, extraSelector = "") => {
  return `${switchScopeSelector(switchId)} ${promotionTargetSelector(promotionTarget)}${extraSelector}`
}

export var Switch = {
  init: function() {
    this.handlePromoteClicks();
    this.handleConfirmPromotionClicks();
    this.handleQuitPromotionClicks();
  },

  afterResize: function(switchId) {
    let triggerEvent = Switch.selectedTriggerEvent(switchId);

    if (triggerEvent) {
      TriggerEvent.alignExpandedPipeline(triggerEvent)
    }
  },

  selectedTriggerEvent: function(switchId) {
    let selectedTriggerEvent = $(`[trigger-event][selected][data-switch="${escapeSelector(switchId)}"]`);

    if (selectedTriggerEvent.length > 0) {
      return selectedTriggerEvent;
    } else {
      return null;
    }
  },

  handlePromoteClicks: function() {
    $("body").on("click", "[promote-button]", function(event) {
      Pollman.stop();

      TargetParams.init('[data-promotion-param-name]');
      let button = $(event.currentTarget);
      let switchId = Switch.parentSwitch(button);
      let promotionTarget = Switch.parentPromotionTarget(button);
      Switch.askToConfirmPromotion(switchId, promotionTarget);

      // Focus on first input or select in the promotion box
      const promotionForm = $(promotionTargetSelector(promotionTarget));
      const firstInput = promotionForm.find('input, select').first();
      if (firstInput.length) {
        if (firstInput[0].tomselect) {
          firstInput[0].tomselect.control.focus();
        } else {
          firstInput[0].focus();
          // Position cursor at the end of the text if there's a value
          if (firstInput[0].value) {
            firstInput[0].setSelectionRange(firstInput[0].value.length, firstInput[0].value.length);
          }
        }
      }

      Switch.afterResize(switchId);
    })
  },

  handleConfirmPromotionClicks: function() {
    $("body").on("click", "[confirm-promotion]", function(event) {
      event.preventDefault()

      let form = $(event.currentTarget).closest("form")

      if(Switch.hasEmptyRequiredParameter(form)) {
        Switch.highlightMissingRequiredParameter(form)
        return;
      }

      let parentPromotionTarget = Switch.parentPromotionTarget($(event.currentTarget))
      let parentPromotionSwitch = Switch.parentSwitch($(event.currentTarget))

      let promotion = Switch.promote(form, parentPromotionSwitch, parentPromotionTarget)

      promotion.done(function() {
        Pollman.start();
      });

      promotion.fail(function() {
        Pollman.start();
        alert("Something went wrong. Please try again.");

        const promoteButtonSelector = promotionScopedSelector(parentPromotionSwitch, parentPromotionTarget, "[promote-button]");
        $(promoteButtonSelector).removeAttr("disabled");
        $(promoteButtonSelector).removeClass("btn-working");
      });
    })
  },

  handleQuitPromotionClicks: function() {
    $("body").on("click", "[quit-promotion]", function(event) {
      event.preventDefault()

      let target = $(event.currentTarget)

      let promotionTarget = Switch.parentPromotionTarget(target)
      let promotionSwitch = Switch.parentSwitch(target)

      const confirmationSelector = promotionScopedSelector(promotionSwitch, promotionTarget, "[promote-confirmation]");
      const promoteButtonSelector = promotionScopedSelector(promotionSwitch, promotionTarget, "[promote-button]");
      $(confirmationSelector).hide();
      $(promoteButtonSelector).show();

      Pollman.pollNow();
      Pollman.start();
      Switch.afterResize(promotionSwitch);
    })
  },

  hasEmptyRequiredParameter: function(form) {
    let inputs = $(form).find("input[required]").filter(function() {
      return $(this).val().trim() === "";
    })

    let selects = $(form).find("select[required]").filter(function() {
      return $(this).val() === null;
    })

    return inputs.length + selects.length > 0
  },

  highlightMissingRequiredParameter: function(form) {
    let inputs = $(form).find("input[required]").filter(function() {
      return $(this).val().trim() === "";
    })

    let selects = $(form).find("select[required]").filter(function() {
      return $(this).val() === null;
    })

    inputs.addClass("form-control-error")
    selects.addClass("form-control-error")

    setTimeout(function() {
      inputs.removeClass("form-control-error")
      selects.removeClass("form-control-error")
    }, 2000)
  },

  askToConfirmPromotion: function(promotionSwitch, promotionTarget) {
    Switch.hidePromotionBoxElements(promotionSwitch, promotionTarget);
    const confirmationSelector = promotionScopedSelector(promotionSwitch, promotionTarget, "[promote-confirmation]");
    $(confirmationSelector).show();
  },

  hidePromotionBoxElements: function(promotionSwitch, promotionTarget) {
    const promotionBoxSelector = promotionScopedSelector(promotionSwitch, promotionTarget, "[promotion-box]");
    $(promotionBoxSelector).children().hide();
  },

  showPromotingInProgress(promotionSwitch, promotionTarget) {
    const confirmationSelector = promotionScopedSelector(promotionSwitch, promotionTarget, "[promote-confirmation]");
    const promoteButtonSelector = promotionScopedSelector(promotionSwitch, promotionTarget, "[promote-button]");
    $(confirmationSelector).hide();
    $(promoteButtonSelector).show();
    $(promoteButtonSelector).attr("disabled", "");
    $(promoteButtonSelector).addClass("btn-working");
    Switch.afterResize(promotionSwitch);
  },

  promote: function(form, promotionSwitch, promotionTarget) {
    Switch.showPromotingInProgress(promotionSwitch, promotionTarget);

    return $.ajax({
      url: form.attr("action"),
      data: $(form).serialize(),
      type: "POST",
      beforeSend: function(xhr) {
        xhr.setRequestHeader("X-CSRF-Token", $("meta[name='csrf-token']").attr("content"));
      }
    });
  },

  latestTriggerEvent: function(promotionSwitch, promotionTarget) {
    return $(promotionScopedSelector(promotionSwitch, promotionTarget, "[trigger-event]")).first();
  },

  isProcessed: function(triggerEvent) {
    return (triggerEvent && (triggerEvent.attr("data-trigger-event-processed") == "true"))
  },

  parentSwitch: function(target) {
    return target.attr("data-switch");
  },

  parentPromotionTarget: function(target) {
    return target.attr("data-promotion-target");
  }
};
