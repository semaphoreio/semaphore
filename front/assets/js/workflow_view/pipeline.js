import $ from "jquery"

import { Diagram } from "./diagram"

export var Pipeline = {
  render_placeholder: function(marginTop) {
    return `
      <div class="dib v-top" style="margin-top: ${marginTop}px;">
        <div style="margin-top: 25px;"></div>
      </div>
    `
  },

  render: function(ancestorId, href, marginTop, pipeline) {
    return `
      <div class="dib v-top" style="margin-top: ${marginTop}px" href="${href}">
        ${pipeline}
      </div>
      <div class="dib v-top successors" successors ancestor="${ancestorId}">
      </div>
    `
  }
};
