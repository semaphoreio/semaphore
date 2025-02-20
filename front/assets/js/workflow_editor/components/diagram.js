import $ from "jquery";
import { graphlib, render } from 'dagre-d3'
import { select } from 'd3-selection'
import { curveBasis } from 'd3-shape'

import { SelectionRegister } from "../selection_register"
import { BlockTemplate     } from "../templates/diagram/block"
import { PipelineTemplate  } from "../templates/diagram/pipeline"

export class Diagram {
  constructor(editor, model, outputDivSelector) {
    this.editor = editor
    this.model = model
    this.outputDivSelector = outputDivSelector
    this.isVisible = false

    this.handleAddBlockClicks()
    this.handleSelectionClick()
    this.handleHoverOnSelectableElements()
    this.handleAddPromotion()
    this.handlePromotionClick()
    this.handleAfterPipelineConfigureClick()
    this.handleAfterPipelineEditClick()

    this.disableRendering = false
  }

  hide() {
    if(!this.isVisible) return;

    $(this.outputDivSelector).hide()
    this.isVisible = false

    this.update()
  }

  show() {
    if(this.isVisible) return;

    $(this.outputDivSelector).show()
    this.isVisible = true

    this.update()
  }

  handleAddBlockClicks() {
    $(this.outputDivSelector).on("click", "[data-action=addBlock]", (e) => {
      let uid = $(e.currentTarget).attr("data-pipeline-uid")
      let pipeline = SelectionRegister.lookup(uid)
      let block = pipeline.createNewBlock()

      SelectionRegister.setCurrentSelectionUid(block.uid)

      e.stopPropagation();
    })
  }

  handlePromotionClick() {
    $(this.outputDivSelector).on("click", "[data-action=expandPromotion]", (e) => {
      e.stopPropagation()

      this.disableRendering = true

      let uid = $(e.currentTarget).attr("data-promotion-uid")
      let promotion = SelectionRegister.lookup(uid)

      if(this.model.expanded.isExpanded(promotion)) {
        this.model.expanded.collapse(promotion)
      } else {
        this.model.expanded.expand(promotion)
      }

      this.disableRendering = false

      SelectionRegister.setCurrentSelectionUid(uid)
    })
  }

  handleAddPromotion() {
    $(this.outputDivSelector).on("click", "[data-action=addPromotion]", (e) => {
      let uid = $(e.currentTarget).attr("data-pipeline-uid")
      let pipeline = SelectionRegister.lookup(uid)

      this.disableRendering = true

      let promotion = pipeline.addPromotion()

      this.model.expanded.expand(promotion)

      this.disableRendering = false

      SelectionRegister.setCurrentSelectionUid(promotion.uid)
    })
  }

  handleAfterPipelineConfigureClick() {
    $(this.outputDivSelector).on("click", "[data-action=configureAfterPipeline]", (e) => {
      let uid = $(e.currentTarget).attr("data-pipeline-uid")
      let pipeline = SelectionRegister.lookup(uid)

      pipeline.afterPipeline.addJob({"name": "Job #1"})

      SelectionRegister.setCurrentSelectionUid(pipeline.afterPipeline.uid)
    })
  }

  handleAfterPipelineEditClick() {
    $(this.outputDivSelector).on("click", "[data-action=editAfterPipeline]", (e) => {
      let uid = $(e.currentTarget).attr("data-pipeline-uid")
      let pipeline = SelectionRegister.lookup(uid)

      SelectionRegister.setCurrentSelectionUid(pipeline.afterPipeline.uid)
    })
  }

  handleSelectionClick() {
    $(this.outputDivSelector).on("click", "[data-uid]", (e) => {
      let uid = $(e.currentTarget).attr("data-uid")

      let ref = SelectionRegister.lookup(uid)

      if(ref !== null) {
        SelectionRegister.setCurrentSelectionUid(uid)
        e.stopPropagation();
      } else {
        console.log(`Current Selection ref not found + ${uid}`)
      }
    })
  }

  handleHoverOnSelectableElements() {
    $(this.outputDivSelector).on("mouseover", "[data-uid]", (e) => {
      e.stopPropagation()
      let uid = $(e.currentTarget).attr("data-uid")

      if(uid && uid !== SelectionRegister.getCurrentSelectionUid()) {
        $(this.outputDivSelector).find("[data-uid]").removeClass("wf-edit-hover")
        $(e.currentTarget).addClass("wf-edit-hover")
      }
    })

    $(this.outputDivSelector).on("mouseout", "[data-uid]", (e) => {
      e.stopPropagation()
      let uid = $(e.currentTarget).attr("data-uid")

      if(uid && uid !== SelectionRegister.getCurrentSelectionUid()) {
        $(e.currentTarget).addClass("wf-edit-hover")
      }
    })
  }

  //
  // Utility method to preserve the location of the scroll pane when
  // re-rendering.
  //
  preserveScrollPositions(fun) {
    let oldTop  = $(this.outputDivSelector).scrollTop()
    let oldLeft = $(this.outputDivSelector).scrollLeft()

    fun()

    setTimeout(() => {
      $(this.outputDivSelector).scrollTop(oldTop)
      $(this.outputDivSelector).scrollLeft(oldLeft)
    }, 10)
  }

  update() {
    if(!this.isVisible) return;
    if(this.disableRendering) return;

    this.preserveScrollPositions(() => {
      let output = ""

      this.model.expanded.pipelines().forEach(p => {
        if(!p.hasInvalidYaml()) {
          output += PipelineTemplate.renderPipeline(this, p)
        } else {
          output += PipelineTemplate.renderYAMLError(p)
        }
      })

      $(this.outputDivSelector).html(output)

      this.model.expanded.pipelines().forEach(p => {
        if (!p.hasInvalidYaml()) {
          this.renderBlocks(p)
        }
      })

      this.model.expanded.expandedPromotions.forEach(promotion => {
        if (!promotion.pipeline.hasInvalidYaml()) {
          let pipeline = promotion.targetPipeline()

          let diagram = $(this.outputDivSelector)
          let pipelineDiv = diagram.find(`[data-uid=${pipeline.uid}]`)
          let promotionDiv = diagram.find(`[data-promotion-uid=${promotion.uid}]`)
          let promotionsDiv = diagram.find(`[data-promotions][data-pipeline-uid=${pipeline.uid}]`).parent()

          if (promotionsDiv.length >= 0) {
            let top = promotionDiv.offset().top - diagram.offset().top - parseInt(diagram.css("padding-top"), 10)

            pipelineDiv.css({ "margin-top": top })
            promotionsDiv.css({ "margin-top": top })
          }
        }
      })

    })
  }

  renderBlocks(pipeline) {
    var g = new graphlib.Graph()

    g.setGraph({
      rankdir: "LR",
      ranksep: 50,
      nodesep: 50,
      align: "UL",
      ranker: "longest-path",
      marginx: 10,
      marginy: 10
    })

    g.setDefaultEdgeLabel(function() { return {}; });

    var svg = $(this.outputDivSelector).find(`[data-uid=${pipeline.uid}] svg`);

    // Foreigh objects (html elements) in a SVG panel get only the necessary
    // height/width to be displayed. Our selection CSS uses box-shadows that
    // goes outside of this area.
    //
    // To fix this I'm adding a 10px margin around the block to have the
    // necessary space to display the drop-shadow.
    //
    // Appart from that, I'm also adding a negative -12px padding to make sure
    // that the edges are actually connected to the block and not only to the
    // outer margin.
    //
    // The padding needs to be bigger than the margin for the edges to connect.
    //
    // (it's a nasty hack... I know)

    pipeline.blocks.forEach((block) => {
      g.setNode(block.uid, {
        labelType: "html",
        label: BlockTemplate.renderBlock(block),
        padding: -10
      });
    });

    pipeline.blocks.forEach((block) => {
      block.dependencies.listBlockUids().forEach((uid) => {
        g.setEdge(uid, block.uid, {
          arrowhead: 'undirected',
          style: "stroke: gray; fill: transparent;",
          curve: curveBasis
        })
      })
    });

    // Create the renderer
    var r = new render();

    // Run the renderer. This is what draws the final graph.
    r(select(`${this.outputDivSelector} [data-uid=${pipeline.uid}] svg`), g);

    // Adjust svg size for the newly created svg diagram
    let outputNode     = svg.find("g.output")[0]
    let outputNodeSize = outputNode.getBoundingClientRect()

    svg.attr("width", Math.max(outputNodeSize.width, g.graph().width))
    svg.attr("height", Math.max(outputNodeSize.height, g.graph().height))

    //
    // Dagre.js draws an ugly white rectangle around every block. Our blocks
    // have a border radious set, so the uglyness is showing itself around the
    // border.
    //
    // I'm basically stabbing Dagre.js in its back and hiding that ugly rect.
    svg.find(".label-container").css({
      "fill": "transparent",
      "stroke": "transparent"
    })
  }
}
