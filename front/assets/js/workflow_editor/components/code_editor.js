import $ from "jquery";
import { delegate } from 'tippy.js';
import CodeMirror from 'codemirror';
import 'codemirror/mode/yaml/yaml.js';

var GUTTER_ID = "CodeMirror-lint-markers";

export class CodeEditor {
  constructor(outputDivSelector) {
    this.outputDivSelector = outputDivSelector

    this.doc = CodeMirror($(this.outputDivSelector)[0], {
      lineNumbers: true,
      mode:  "yaml",
      tabSize: 2,
      gutters: [
        "CodeMirror-linenumbers",
        "CodeMirror-lint-markers"
      ],
      viewportMargin: Infinity
    });

    this.doc.on("changes", this.handleChanges.bind(this))

    this.updatePanelSize()
    this.registerPanelSizeHandler()

    this.isVisible = true
    this.rendering = false

    delegate("body", {
      target: ".CodeMirror-lint-marker-error"
    })

    this.activePipeline = null
  }

  hide() {
    if(!this.isVisible) return;

    $(this.outputDivSelector).hide()
    this.isVisible = false

    this.update()
  }

  show(pipeline) {
    if(this.isVisible && this.activePipeline === pipeline) return;

    this.ignoreUpdate = true
    this.activePipeline = pipeline
    this.doc.setValue(this.activePipeline.toYaml())
    this.ignoreUpdate = false

    $(this.outputDivSelector).show()
    this.isVisible = true

    this.update()
  }

  handleChanges() {
    if(this.ignoreUpdate) return;

    this.activePipeline.updateYaml(this.doc.getValue())
  }

  //
  // Used in tests to update the content of the editor.
  //
  // Example:
  //
  //   changeContent("version: 1.0\n...")
  //
  changeContent(content) {
    this.doc.setValue(content)
  }

  updatePanelSize() {
    let panel = $(this.outputDivSelector)
    let height = $(window).height() - panel.offset().top

    panel.css({"height": height - 50 + "px"})
    panel.find(".CodeMirror").css({"height": "100%"})
  }

  registerPanelSizeHandler() {
    // update size on every window size change
    $(window).on("resize", () => this.updatePanelSize())
  }

  update() {
    if(!this.isVisible) return;

    this.renderErrorMarks()
    this.updatePanelSize()
    this.doc.refresh()
  }

  renderErrorMarks() {
    if(!this.activePipeline) return;

    this.doc.clearGutter(GUTTER_ID)

    if(this.activePipeline.hasInvalidYaml()) {
      let line = this.activePipeline.yamlError.mark.line
      let message = this.activePipeline.yamlError.reason

      let marker = $("<div>")
        .attr("data-tippy-content", message)
        .attr("data-tippy-arrow", "true")
        .attr("data-tippy-placement", "right")
        .addClass("CodeMirror-lint-marker-error")

      this.doc.setGutterMarker(line, GUTTER_ID, marker[0])
    }
  }
}
