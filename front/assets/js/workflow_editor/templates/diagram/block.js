import { SelectionRegister } from "../../selection_register"

import { Job } from "./job"

function renderBlock(block) {
  let klass = "link dib v-top dark-gray bg-white shadow-1 pa2 br2"

  if(block.errors.exists()) {
    klass = klass + " wf-edit-has-error"
  }

  // Foreigh objects (html elements) in a SVG panel get only the necessary
  // height/width to be displayed. Our selection CSS uses box-shadows that goes
  // outside of this area.
  //
  // To fix this I'm adding a 10px margin around the block to have the necessary
  // space to display the drop-shadow.
  let style = "margin: 10px; min-width: 100px;"

  if(block.uid === SelectionRegister.getCurrentSelectionUid()) {
    klass += " wf-edit-selected"
  }

  return `
    <a href="#" style="${style}" class="${ klass }" data-type=block data-uid=${ block.uid }>
      <h4 class="f4 normal gray mb2">${ escapeHtml(block.name) }</h4>

      ${ block.jobs.map(j => Job.render(j)).join("") }
    </a>
  `
}

export var BlockTemplate = {
  renderBlock: renderBlock
}
