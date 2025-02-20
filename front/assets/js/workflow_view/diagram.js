import $ from "jquery"
import { graphlib, render } from 'dagre-d3'
import { select } from 'd3-selection'
import { curveBasis } from 'd3-shape'

export var Diagram = {
  html: function(html) {
    $("#diagram-container").html(html);
  },

  append: function(pipeline) {
    $("#diagram").append(pipeline);
  },

  positionFromTop: function() {
    return $("#diagram").offset().top;
  },

  draw: function(pipeline_id) {
    var g = new graphlib.Graph()
    .setGraph({
      rankdir: "LR",
      ranksep: 50,
      nodesep: 50,
      align: "UL",
      ranker: "longest-path",
      marginx: 10,
      marginy: 10
    })
    .setDefaultEdgeLabel(function() { return {}; });

    var toggleInput = $("input[name=showSkippedBlocks]")
    var showSkipped = !(toggleInput.length) || toggleInput.prop("checked");

    var svg = $(`svg[pipeline=${pipeline_id}]`);
    var nodes = JSON.parse(svg.attr("nodes"));

    svg.empty();

    nodes.forEach(function(node) {
      if (showSkipped || !node.skipped) {
        g.setNode(node.name, {
          labelType: "html",
          label: node.html,
          padding: -12
        });
      }
    });

    var edges = JSON.parse(svg.attr(showSkipped ? "edges" : "indirect_edges"));

    edges.forEach(function(edge) {
      g.setEdge(edge.source, edge.target, {
        arrowhead: 'undirected',
        style: `stroke: ${edge.color}; fill: transparent;`,
        curve: curveBasis
      })
    });

    // Create the renderer
    var r = new render();

    // Run the renderer. This is what draws the final graph.
    r(select(`svg[pipeline='${pipeline_id}']`), g);

    // Adjust svg size for the newly created svg diagram
    let outputNode     = svg.find("g.output")[0]
    let outputNodeSize = outputNode.getBoundingClientRect()

    svg.attr("width", Math.max(outputNodeSize.width, g.graph().width))
    svg.attr("height", Math.max(outputNodeSize.height, g.graph().height))

    svg.find(".label-container").css({
      "fill": "transparent",
      "stroke": "transparent"
    })

    svg.find("g.label").removeClass("label")
  }
};
