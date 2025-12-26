import { SelectionRegister } from "../../selection_register"
import { AfterPipeline } from "./after_pipeline"
import { Features } from "../../../features"

function addBlock(pipeline) {
  return `
    <div class="dib v-top pl3 ml3 bl b--lighter-gray">
      <div data-action="addBlock" data-pipeline-uid=${pipeline.uid} class="f4 dib v-top ba b--dashed bw1 mid-gray hover-dark-gray ph3 pv3 br2 pointer">
        + Add Block
      </div>
    </div>`
}

function renderPromotions(diagram, pipeline) {
  // Skip rendering promotions if the feature flag is enabled
  if (Features.isEnabled('hidePromotions')) {
    return '';
  }

  let promotions = pipeline.promotions.map(promotion => {
    let klass1 = "f4 bg-white shadow-1 br2 mb3 pointer"
    let klass2 = "ph2 pv1 br2 pointer"

    if(promotion.errors.exists()) {
      klass2 = klass2 + " wf-edit-has-error"
    }

    if(diagram.model.expanded.isExpanded(promotion)) {
      klass1 += " wf-switch-item-selected"
    }

    if(promotion.uid === SelectionRegister.getCurrentSelectionUid()) {
      klass2 += " wf-edit-selected"
    }

    let automatic = ""
    if(promotion.isAutomatic()) {
      automatic = `<span class="f7 fw6 bg-gray white br1 ph1 ml2">A</span>`
    }

    return `
      <div data-action=expandPromotion data-promotion-uid=${promotion.uid} class="${klass1}">
        <div class="${klass2}">
          ${escapeHtml(promotion.name)} ${automatic}
        </div>
      </div>
      `
  }).join("\n")

  let title = `
    <div class="mb2 pb1 nt1">
      <div class="flex justify-between mb1">
        <label class="f4 normal gray mb0 pb0">Promotions</label>

        <a href="https://docs.semaphoreci.com/using-semaphore/promotions" target="_blank" rel="noopener" class="f6 gray default-tip" data-tippy="" data-original-title="Help: What are promotions?">?</a>
      </div>
    </div>`

  let addPromotion = `<div data-action=addPromotion data-pipeline-uid=${pipeline.uid} class="f4 dib v-top w-100 ba b--dashed bw1 mid-gray hover-dark-gray ph3 pv1 br2 pointer">+ Add Promotion</div>`

  return `<div class="pa3" data-promotions data-pipeline-uid=${pipeline.uid}>
    ${title}
    ${promotions}
    ${addPromotion}
  </div>`
}

function renderPromotionsAndAfterPipeline(diagram, pipeline) {
  return `
    <div class="dib relative v-top bg-washed-gray ba b--black-075 br3 mr3">
      ${AfterPipeline.render(pipeline)}
      ${renderPromotions(diagram, pipeline)}
    </div>
  `
}

function renderPipeline(diagram, pipeline) {
  let klass = "dib v-top bg-washed-gray pa3 br3 ba b--black-075 mr3"

  klass += " wf-pipeline-has-switch"

  if(pipeline.errors.exists()) {
    klass = klass + " wf-edit-has-error"
  }

  if(pipeline.uid === SelectionRegister.getCurrentSelectionUid()) {
    klass += " wf-edit-selected"
  }

  return `
    <div data-type=pipeline data-uid=${pipeline.uid} class="${klass}">
      <div class="mb2 pb1 nt1">
        <h3 class="f4 normal gray mb0 pr3">${ escapeHtml(pipeline.name) }</h3>
      </div>

      <!-- This is where the blocks will be rendered by the view -->
      <svg></svg>

      ${ addBlock(pipeline) }
    </div>

    ${ renderPromotionsAndAfterPipeline(diagram, pipeline) }
  `
}

function renderYAMLError(pipeline) {
  return `
    <p class=red>Invalid YAML syntax in .semaphore/semaphore.yml</p>

    <div class="f5 code ws-normal bg-white pa2 br2 shadow-1">
      <code>error message: ${pipeline.yamlError.reason}</code>
      <br />
      <code></code>
      <br />
      <code>line: ${pipeline.yamlError.mark.line}</code>
      <br />
      <code>column: ${pipeline.yamlError.mark.column}</code>
    </div>
  `
}

export var PipelineTemplate = {
  renderPipeline: renderPipeline,
  renderYAMLError: renderYAMLError
}
