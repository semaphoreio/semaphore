var ACTIVE = "link dib dark-gray b"
var INACTIVE = "dib"

export class TabsTemplate {

  static render(component) {
    return `
      <span>Edit with </span>
      ${this.visual(component)}

      <span> or edit individual .yml files: </span>
      ${this.yamls(component)}
    `
  }

  static visual(component) {
    let active = component.active === "visual"
    let name = "Visual Builder"
    let mark = active ? "✓ " : ""

    return `
      <a href="#"
         data-action=changeTab
         data-target="visual"
         class="${this.linkClass(active)}">${mark}${name}</a>
    `
  }

  static yamls(component) {
    return component.editor.workflow.naturallySortedPipelines().map(p => {
      let active = component.active === "code" && component.pipeline === p

      let name = p.filePath.replace(".semaphore/", "")
      let mark = active ? "✓ " : ""

      return `
        <a href="#"
          data-action=changeTab
          data-target="code"
          data-pipeline-uid="${p.uid}"
          class="${this.linkClass(active)}">${mark}${name}</a>`
    }).join(", ")
  }

  static linkClass(active) {
    if(active) {
      return ACTIVE
    } else {
      return INACTIVE
    }
  }

}
