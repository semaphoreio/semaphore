import $ from "jquery"

import { TriggerEvent } from "./trigger_event"
import { Pollman } from "../pollman"
import { TargetParams } from "./target_params"
import { Utils } from "../utils"

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
    let selectedTriggerEvent = $(`[trigger-event][selected][data-switch='${switchId}']`);

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
      const escapedPromotionTarget = Utils.escapeCSSAttributeValue(promotionTarget);
      const promotionForm = $(`[data-promotion-target="${escapedPromotionTarget}"]`);
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

        let escapedTarget = Utils.escapeCSSAttributeValue(parentPromotionTarget);
        $(`[switch='${parentPromotionSwitch}'] [data-promotion-target='${escapedTarget}'][promote-button]`).removeAttr("disabled");
        $(`[switch='${parentPromotionSwitch}'] [data-promotion-target='${escapedTarget}'][promote-button]`).removeClass("btn-working");
      });
    })
  },

  handleQuitPromotionClicks: function() {
    $("body").on("click", "[quit-promotion]", function(event) {
      event.preventDefault()

      let target = $(event.currentTarget)

      let promotionTarget = Switch.parentPromotionTarget(target)
      let promotionSwitch = Switch.parentSwitch(target)
      let escapedTarget = Utils.escapeCSSAttributeValue(promotionTarget);

      $(`[switch='${promotionSwitch}'] [data-promotion-target='${escapedTarget}'][promote-confirmation]`).hide();
      $(`[switch='${promotionSwitch}'] [data-promotion-target='${escapedTarget}'][promote-button]`).show();

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
    let escapedTarget = Utils.escapeCSSAttributeValue(promotionTarget);
    $(`[switch='${promotionSwitch}'] [data-promotion-target='${escapedTarget}'][promote-confirmation]`).show();
  },

  hidePromotionBoxElements: function(promotionSwitch, promotionTarget) {
    let escapedTarget = Utils.escapeCSSAttributeValue(promotionTarget);
    $(`[switch='${promotionSwitch}'] [promotion-box][data-promotion-target='${escapedTarget}']`).children().hide();
  },

  showPromotingInProgress(promotionSwitch, promotionTarget) {
    let escapedTarget = Utils.escapeCSSAttributeValue(promotionTarget);
    $(`[switch='${promotionSwitch}'] [data-promotion-target='${escapedTarget}'][promote-confirmation]`).hide();
    $(`[switch='${promotionSwitch}'] [data-promotion-target='${escapedTarget}'][promote-button]`).show();
    $(`[switch='${promotionSwitch}'] [data-promotion-target='${escapedTarget}'][promote-button]`).attr("disabled", "");
    $(`[switch='${promotionSwitch}'] [data-promotion-target='${escapedTarget}'][promote-button]`).addClass("btn-working");
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
    let escapedTarget = Utils.escapeCSSAttributeValue(promotionTarget);
    return $(`[switch='${promotionSwitch}'] [trigger-event][data-promotion-target='${escapedTarget}']`).first();
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
