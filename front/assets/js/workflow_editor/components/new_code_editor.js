import { render } from 'preact';
import { YamlEditor } from '../../project_onboarding/new/components/yaml_editor';
import { MarkerSeverity, editor } from 'monaco-editor';

const GUTTER_ID = "CodeMirror-lint-markers";

export class CodeEditor {

  constructor(outputDivSelector) {
    this.outputDivSelector = outputDivSelector;

    this.editorRef = null; // Store Monaco editor reference

    this.state = {
      value: '', 
      readOnly: false,
    };

    this.handleChange = this.handleChange.bind(this);
    this.initEditor();
    this.registerPanelSizeHandler();
  }

  initEditor() {
    const container = document.querySelector(this.outputDivSelector);

    if (container) {
      render(
        <YamlEditor
          ref={(ref) => {
            this.editorRef = ref; // Store Monaco editor reference
          }}
          value={this.state.value}
          onChange={this.handleChange}
          readOnly={this.state.readOnly}
        />,
        container
      );
    }
  }

  handleChange(newValue) {
    this.state.value = newValue;
    this.activePipeline.updateYaml(this.state.value);

    // Only update markers, not re-render the component
    this.renderErrorMarks();
  }

  show(pipeline) {
    this.activePipeline = pipeline;
    this.state.value = pipeline.toYaml();

    // Directly update Monaco's value
    this.editorRef?.setValue(this.state.value);
  }

  renderErrorMarks() {
    if (!this.activePipeline) return;

    const errors = this.activePipeline.getYamlErrors(); // Same logic from CodeMirror

    const markers = errors.map(error => ({
      severity: MarkerSeverity.Error,
      message: error.reason,
      startLineNumber: error.mark.line + 1,
      startColumn: 1,
      endLineNumber: error.mark.line + 1,
      endColumn: 100,
    }));

    const model = this.editorRef?.getModel();
    if (model) {
      editor.setModelMarkers(model, GUTTER_ID, markers);
    }
  }

  update() {
    this.renderErrorMarks();
  }

  hide() {
    const container = document.querySelector(this.outputDivSelector);
    if (container) {
      render(null, container);
    }
  }

  registerPanelSizeHandler() {
    window.addEventListener("resize", () => this.updatePanelSize());
  }

  updatePanelSize() {
    const container = document.querySelector(this.outputDivSelector);
    if (!container) return;

    const height = window.innerHeight - container.offsetTop;

    const layoutInfo = this.editorRef.getLayoutInfo();
    this.editorRef.layout({ width: layoutInfo.width, height });
  }
}