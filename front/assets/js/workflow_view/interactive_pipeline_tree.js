import $ from "jquery"

import { Pollman } from "../pollman"
import { Http } from "../http"
import { GlobalState } from "../global_state"
import { Diagram } from "./diagram"
import { Notice } from "../notice"
import _ from "lodash";

export var InteractivePipelineTree = {
  init: function(opts = {}) {
    InteractivePipelineTree.handleWorkflowTreeItemClicks(opts);
    InteractivePipelineTree.handlePipelineStopClicks();
    InteractivePipelineTree.handlePipelineRebuildClicks();
    InteractivePipelineTree.handleToggleSkippedBlocksClicks();
  },

  handlePipelineStopClicks: function() {
    $("body").on("click", "[pipeline-stop-button]", function(event) {
      event.preventDefault();
      let button = $(event.currentTarget);
      let href = button.attr("href");
      button.text("Stopping...")
      button.attr("disabled", true);

      let req = $.ajax({
        url: href,
        type: "POST",
        beforeSend: function(xhr) {
          xhr.setRequestHeader("X-CSRF-Token", $("meta[name='csrf-token']").attr("content"));
        }
      });

      req.done(function(data) {
        if(data.error != undefined) {
          Notice.error(data.error)
        } else {
          Notice.notice(data.message)
        }
        button.remove();
      })
    });
  },

  handlePipelineRebuildClicks: function() {
    $("body").on("click", "[pipeline-rebuild-button]", function(event) {
      event.preventDefault();
      let button = $(event.currentTarget);
      let href = button.attr("href");
      button.text("Rebuilding...")
      button.attr("disabled", true);

      let req = $.ajax({
        url: href,
        type: "POST",
        beforeSend: function(xhr) {
          xhr.setRequestHeader("X-CSRF-Token", $("meta[name='csrf-token']").attr("content"));
        }
      });

      req.done(function(data) {
        if(data.error != undefined) {
          Notice.error(data.error)
          button.text("Rebuild Pipeline")
          button.attr("disabled", false);
        } else {
          Notice.notice(data.message)
          button.remove();
        }
      })
    });
  },

  onWorkflowTreeItemClick: function(event) {
    let pipelineId = $(event.currentTarget).data("pipeline-id");

    let pipelinePathUrl = $(event.currentTarget).data("pipeline-path-url");

    Pollman.stop(); // Stop Pollman to change the state of the tree view
    InteractivePipelineTree.indicateLoadingPipeline(pipelineId);
    Http.get(pipelinePathUrl, function(response) {
      return response.text().then(function(content) {
        InteractivePipelineTree.selectPipeline(pipelineId);
        Diagram.html(content);
          Pollman.start();
      });
    })
  },

  handleWorkflowTreeItemClicks: function(opts) {
    if(opts.onWorkflowTreeItemClick) {
      $("body").on("click", "[workflow-tree-item]", _.bind(opts.onWorkflowTreeItemClick, this));
    } else {
      $("body").on("click", "[workflow-tree-item]", this.onWorkflowTreeItemClick);
    }
  },

  removeSpinners: function() {
    $("[workflow-tree-item-spinner]").remove();
  },

  selectPipeline: function(pipelineId) {
    InteractivePipelineTree.removeSpinners();
    $(`[workflow-tree-item]`).addClass("hide-child");
    $(`[workflow-tree-item][data-pipeline-id='${pipelineId}']`).removeClass("hide-child");

    let pipelineStatusUrl = $(`[workflow-tree-item][data-pipeline-id='${pipelineId}']`).data("pipelineStatusUrl");
    if(pipelineStatusUrl && window.FaviconUpdater) {
      window.FaviconUpdater.setPipelineStatusUrl(pipelineStatusUrl);
    }

    let container = document.querySelector("#workflow-tree-container")
    container.setAttribute("data-poll-param-pipeline_id", pipelineId)

    InteractivePipelineTree.setState(pipelineId);
  },

  indicateLoadingPipeline: function(pipelineId) {
    InteractivePipelineTree.removeSpinners();

    let treeItem = $(`[workflow-tree-item][data-pipeline-id='${pipelineId}']`);
    treeItem.append(`
                    <span workflow-tree-item-spinner class="flex items-center ml2">
                    <img src="/projects/assets/images/spinner-2.svg" width="20px"/>
                      </span>
                    `);
  },

  setState: function(pipelineId) {
    GlobalState.set("pipeline_id", pipelineId);
  },

  adjustSuccessorsTopMargins: function() {
    let successorIds = $("[successors] [pipeline]").map(function() {
      return $(this).attr("pipeline");
    }).get();

    successorIds.forEach(function(pipelineId) {
      let triggerEvent = $(`[trigger-event=${pipelineId}]`);
      let originPipelineId = triggerEvent.data("origin-pipeline");
      let additionalOffset = 36;
      let topMargin = triggerEvent.offset().top - $(`[successors][ancestor=${originPipelineId}]`).offset().top - additionalOffset;

      $(`[pipeline-container=${pipelineId}]`).css("margin-top", topMargin);
    });
  },

  handleToggleSkippedBlocksClicks: function() {
    $("body").on("click", "button[name=toggleSkippedBlocks]", function(event) {
      event.preventDefault();

      let showSkippedBlocks = !($("input[name=showSkippedBlocks]").prop('checked'))
      let buttonText = showSkippedBlocks ? "Hide skipped blocks" : "Show skipped blocks"

      $("input[name=showSkippedBlocks]").prop('checked', showSkippedBlocks)
      $("button[name=toggleSkippedBlocks]").text(buttonText)

      $("svg[pipeline]").each(function() {
        InteractivePipelineTree.redrawDiagrams($(this).attr('pipeline'))
      })
    })
  },

  redrawDiagrams: function(pipelineId) {
    window.Diagram.draw(pipelineId);

    // After drawing the diagram we set the explicit size of the outer container
    // to avoid size jumping before and after rendering the diagram

    wrapper = document.querySelector(`div[pipeline-fixed-size-container="${pipelineId}"]`);
    wrapper.removeAttribute("style");
    wrapper.style.height = wrapper.scrollHeight.toString() + "px";
    wrapper.style.width  = wrapper.scrollWidth.toString() + "px";
  }
}
