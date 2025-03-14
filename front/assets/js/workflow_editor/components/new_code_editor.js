import { render } from 'preact';
import { YamlEditor } from '../../toolbox/yaml_editor';
import { MarkerSeverity } from 'monaco-editor';

const MODEL_OWNER_ID = "WorkflowCodeEditor";

export class CodeEditor {
  constructor(outputDivSelector) {
    this.outputDivSelector = outputDivSelector;
    this.editor = null;
    this.monaco = null;
    this.isRendered = false;

    this.state = {
      value: '', 
    };

    this.handleChange = this.handleChange.bind(this);

    this.registerPanelSizeHandler();
    this.renderEditor();
  }

  renderEditor() {
    const container = document.querySelector(this.outputDivSelector);
    if (container && !this.isRendered) {
      render(
        <YamlEditor
          onMount={(editor, monaco) => {
            this.editor = editor;
            this.monaco = monaco;
            this.updatePanelSize();
          }}
          value={this.state.value}
          onChange={this.handleChange}
        />,
        container
      );
      this.isRendered = true;
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
    if (!this.activePipeline || !this.editor || !this.monaco) return;
    const model = this.editor.getModel();

    this.monaco.editor.removeAllMarkers(MODEL_OWNER_ID);

    if (this.activePipeline.hasInvalidYaml()) {
      
      const yamlError = this.activePipeline.yamlError;

      const line = yamlError.mark.line + 1;
      const startColumn = 1;
      const endColumn = model.getLineLength(line) + 1;
      
      const message = yamlError.reason;

      const markers = [{
        severity: MarkerSeverity.Error,
        message: message,
        startLineNumber: line,
        endLineNumber: line,
        startColumn: startColumn,
        endColumn: endColumn,
      }];

      this.monaco.editor.setModelMarkers(model, MODEL_OWNER_ID, markers);
    }
  }

  update() {
    if (!this.activePipeline || !this.editor || !this.monaco) return;

    const pipelineYaml = this.activePipeline.toYaml();
    if (this.state.value !== pipelineYaml) {
      this.state.value = pipelineYaml;
    }
    this.renderErrorMarks();
  }

  hide() {
    const container = document.querySelector(this.outputDivSelector);
    if (container && this.isRendered) {
      render(null, container);
      this.isRendered = false;
    }
  }

  registerPanelSizeHandler() {
    window.addEventListener("resize", () => this.updatePanelSize());
  }

  updatePanelSize() {
    const container = document.querySelector(this.outputDivSelector);
    if (!container || !this.editor) return;

    const height = window.innerHeight - container.offsetTop - 60;
    const layoutInfo = this.editor.getLayoutInfo();
    this.editor.layout({ width: layoutInfo.width, height });
  }
}
