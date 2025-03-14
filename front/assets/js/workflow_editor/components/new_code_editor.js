import { render } from 'preact';
import { YamlEditor } from '../../project_onboarding/new/components/yaml_editor';
import { MarkerSeverity, editor } from 'monaco-editor';

const MODEL_OWNER_ID = "CodeMirror-lint-markers";

export class CodeEditor {
  constructor(outputDivSelector) {
    this.outputDivSelector = outputDivSelector;
    this.editorRef = null;
    this.isMounted = false;

    this.state = {
      value: '', 
    };

    this.handleChange = this.handleChange.bind(this);

    this.registerPanelSizeHandler();
    this.renderEditor();
  }

  renderEditor() {
    const container = document.querySelector(this.outputDivSelector);
    if (container && !this.isMounted) {
      render(
        <YamlEditor
        ref={(ref) => {
          this.editorRef = ref; // Store Monaco editor reference
          this.updatePanelSize();
        }}
          value={this.state.value}
          onChange={this.handleChange}
        />,
        container
      );
      this.isMounted = true;
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
    const model = this.editorRef.getModel();
    console.log("Model:", model)

    editor.removeAllMarkers(MODEL_OWNER_ID);

    if (this.activePipeline.hasInvalidYaml()) {
      
      const yamlError = this.activePipeline.yamlError;
      console.log(yamlError);

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
      
      console.log("Markers:", markers);
      editor.setModelMarkers(model, MODEL_OWNER_ID, markers);
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
    if (container && this.isMounted) {
      render(null, container);
      this.isMounted = false;
    }
  }

  registerPanelSizeHandler() {
    window.addEventListener("resize", () => this.updatePanelSize());
  }

  updatePanelSize() {
    const container = document.querySelector(this.outputDivSelector);
    if (!container || !this.editorRef) return;

    const height = window.innerHeight - container.offsetTop - 60;
    const layoutInfo = this.editorRef.getLayoutInfo();
    this.editorRef.layout({ width: layoutInfo.width, height });
  }

  getEndOfLineIndex(str, line, fromIndex = 0) {
    let count = 0;
  
    for (let i = fromIndex; i < str.length; i++) {
      if (str[i] === '\n') {
        count++;
        if (count === line) {
          return i;
        }
      }
    }
  
    return -1; // If not found
  }
}
