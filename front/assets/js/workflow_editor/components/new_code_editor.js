import { render } from 'preact';
import { YamlEditor } from '../../project_onboarding/new/components/yaml_editor';
import { MarkerSeverity, editor } from 'monaco-editor';

const GUTTER_ID = "CodeMirror-lint-markers";

export class CodeEditor {
  constructor(outputDivSelector) {
    this.outputDivSelector = outputDivSelector;
    this.editorRef = null;

    this.state = {
      value: '', 
    };

    this.handleChange = this.handleChange.bind(this);

    this.registerPanelSizeHandler();
    this.renderEditor();
  }

  renderEditor() {
    const container = document.querySelector(this.outputDivSelector);

    if (container) {
      render(
        <YamlEditor
        ref={(ref) => {
          console.log('Assigning ref', ref);
          this.editorRef = ref; // Store Monaco editor reference
          this.updatePanelSize();
        }}
          value={this.state.value}
          onChange={this.handleChange}
        />,
        container
      );
    }
  }

  handleChange(newValue) {
    this.state.value = newValue;
    this.activePipeline.updateYaml(this.state.value);
  }

  show(pipeline) {
    this.activePipeline = pipeline;

    this.state.value = pipeline.toYaml();
    this.renderEditor();
  }

  renderErrorMarks() {
    if (!this.activePipeline || !this.editorRef) return;
  
    this.editorRef?.removeAllMarkers(GUTTER_ID);

    if (this.activePipeline.hasInvalidYaml()) {
      const line = this.activePipeline.yamlError.mark.line + 1;
      const column = this.activePipeline.yamlError.mark.column + 1;
      const message = this.activePipeline.yamlError.reason;

      const markers = [{
        severity: MarkerSeverity.Error,
        message: message,
        startLineNumber: line,
        startColumn: column,
        endLineNumber: line,
        endColumn: column,
      }];

      const model = this.editorRef?.getModel();
      if (model) {
        editor.setModelMarkers(model, GUTTER_ID, markers);
      }
    }
  }

  update() {
    if (!this.activePipeline || !this.editorRef) return;

    const pipelineYaml = this.activePipeline.toYaml();
    if (this.state.value !== pipelineYaml) {
      this.state.value = pipelineYaml;
    }
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
    if (!container || !this.editorRef) return;

    const height = window.innerHeight - container.offsetTop;
    const layoutInfo = this.editorRef.getLayoutInfo();
    this.editorRef.layout({ width: layoutInfo.width, height });
  }
}
