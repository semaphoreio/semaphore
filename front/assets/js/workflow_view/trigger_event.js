import $ from "jquery"
import { Diagram } from "./diagram"
import { Pipeline } from "./pipeline"
import { Http } from "../http"
import { GlobalState } from "../global_state"
import { InteractivePipelineTree } from "./interactive_pipeline_tree"

export var TriggerEvent = {
  init: function() {
    TriggerEvent.handleSelections();
  },

  handleSelections: function() {
    $("body").on("click", "[data-trigger-event-processed=true]", function(event) {
      Pollman.stop();
      let triggerEvent = $(event.currentTarget);
      if(TriggerEvent.isSelected(triggerEvent)) {
        TriggerEvent.removeSelections(triggerEvent);
      } else {
        TriggerEvent.removeSelections(triggerEvent);
        TriggerEvent.select(triggerEvent);
      }
      Pollman.start();
      return false;
    });

    $("body").on("click", "[data-trigger-event-processed=false]", function(event) {
      return false;
    });
  },

  select: triggerEvent => {
    InteractivePipelineTree.selectPipeline(triggerEvent.data("triggered-pipeline"))
    TriggerEvent.parentSwitch(triggerEvent).attr("data-poll-param-selected_trigger_event_id", triggerEvent.attr("trigger-event"));
    TriggerEvent.parentPipeline(triggerEvent).attr("data-poll-param-selected_trigger_event_id", triggerEvent.attr("trigger-event"));
    TriggerEvent.collapseSuccessors(triggerEvent);
    TriggerEvent.expandFirstSuccessor(triggerEvent);
    triggerEvent.attr("selected", "true");
    triggerEvent.addClass("wf-switch-item-selected");
    triggerEvent.removeClass("hide-child");
  },

  alignExpandedPipeline: triggerEvent => {
    let originPipelineId = TriggerEvent.originPipelineId(triggerEvent);
    let marginTop = TriggerEvent.positionFromTop(triggerEvent, originPipelineId);

    $(`[successors][ancestor=${originPipelineId}]`).children().first().css("margin-top", marginTop);
  },

  removeSelections: function(triggerEvent) {
    InteractivePipelineTree.selectPipeline(triggerEvent.data("origin-pipeline"))
    TriggerEvent.parentSwitch(triggerEvent).attr("data-poll-param-selected_trigger_event_id", "");
    TriggerEvent.parentPipeline(triggerEvent).attr("data-poll-param-selected_trigger_event_id", "");
    TriggerEvent.collapseSuccessors(triggerEvent);
    var triggerEvents = $(`[trigger-event][data-switch=${TriggerEvent.switchId(triggerEvent)}]`);
    triggerEvents.removeClass("wf-switch-item-selected");
    triggerEvents.addClass("hide-child");
    triggerEvents.removeAttr("selected");
  },

  isSelected: function(triggerEvent) {
    return triggerEvent.attr("selected") ? true : false;
  },

  collapseSuccessors: function(triggerEvent) {
    $(`[successors][ancestor=${TriggerEvent.originPipelineId(triggerEvent)}]`).empty();
  },

  expandFirstSuccessor: function(triggerEvent) {
    var originPipelineId    = TriggerEvent.originPipelineId(triggerEvent);
    var triggeredPipelineId = TriggerEvent.triggeredPipelineId(triggerEvent);
    var marginTop           = TriggerEvent.positionFromTop(triggerEvent, originPipelineId);
    var pipelineHref        = TriggerEvent.triggeredPipelineHref(triggerEvent);
    var placeholder         = Pipeline.render_placeholder(marginTop);
    $(`[successors][ancestor=${TriggerEvent.originPipelineId(triggerEvent)}]`).append(placeholder);
    Http.get(pipelineHref, function(response) {
      response.text().then(function(content) {
        if(TriggerEvent.isSelected(triggerEvent)) {
          let pipeline = Pipeline.render(triggeredPipelineId, pipelineHref, marginTop, content)
          $(`[successors][ancestor=${TriggerEvent.originPipelineId(triggerEvent)}]`).html(pipeline);
        }
      });
    });
  },

  positionFromTop: function(triggerEvent, originPipelineId) {
    var additionalOffset = 36;
    return triggerEvent.offset().top - $(`[successors][ancestor=${TriggerEvent.originPipelineId(triggerEvent)}]`).offset().top - additionalOffset;
  },

  triggeredPipelineHref: function(triggerEvent) {
    return triggerEvent.attr("data-triggered-pipeline-href");
  },

  triggeredPipelineId: function(triggerEvent) {
    return triggerEvent.attr("data-triggered-pipeline");
  },

  originPipelineId: function(triggerEvent) {
    return triggerEvent.attr("data-origin-pipeline");
  },

  switchId: function(triggerEvent) {
    return triggerEvent.attr("data-switch");
  },

  parentSwitch: function(triggerEvent) {
    return $(`[switch=${triggerEvent.attr("data-switch")}]`);
  },

  parentPipeline: function(triggerEvent) {
    return $(`div[data-poll-href][pipeline=${triggerEvent.attr("data-origin-pipeline")}]`);
  }
};
