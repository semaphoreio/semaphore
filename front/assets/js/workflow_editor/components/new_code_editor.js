import { render } from 'preact';
import { YamlEditor } from '../../project_onboarding/new/components/yaml_editor';
import * as monaco from 'monaco-editor';

var GUTTER_ID = "CodeMirror-lint-markers";

export class CodeEditor {
  constructor(outputDivSelector) {
    this.outputDivSelector = outputDivSelector;

    this.state = {
      value: '', 
      readOnly: false,
      errors: []
    };

    this.handleChange = this.handleChange.bind(this);

    this.renderEditor();
  }

  renderEditor() {
    const container = document.querySelector(this.outputDivSelector);

    if (container) {
      render(
        <YamlEditor
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

    // Trigger error rendering after every change
    this.renderErrorMarks();
  }

  show(pipeline) {
    this.state.value = pipeline.toYaml();
    this.renderEditor();
  }

  renderErrorMarks() {
    if (!this.activePipeline) return;

    const errors = this.activePipeline.getYamlErrors(); // Your old logic to get YAML errors

    const markers = errors.map(error => ({
      severity: monaco.MarkerSeverity.Error,
      message: error.reason,
      startLineNumber: error.mark.line + 1,
      startColumn: 1,
      endLineNumber: error.mark.line + 1,
      endColumn: 100,
    }));

    const model = monaco.editor.getModels()[0]; // Monaco's current editor model
    monaco.editor.setModelMarkers(model, GUTTER_ID, markers);
  }

  update() {
    if (!this.isVisible) return;
    this.renderEditor();
    this.renderErrorMarks(); // Re-render markers on update
  }

  hide() {
    const container = document.querySelector(this.outputDivSelector);
    if (container) {
      render(null, container);
    }
  }
}
