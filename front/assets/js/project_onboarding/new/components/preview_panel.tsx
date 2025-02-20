import { h, Fragment } from "preact";
import * as toolbox from "js/toolbox";
import { useState, useContext } from "preact/hooks";
import Editor from '@monaco-editor/react';
import type { Templates } from "../types";
import { WorkflowSetup } from "../stores";
import { PipelinePreview } from "./pipeline_preview";
import Tippy from '@tippyjs/react';

interface PreviewPanelProps {
  template?: Templates.Template;
}

type TabType = `visual` | `yaml`;

export const PreviewPanel = ({ template }: PreviewPanelProps) => {
  const [activeTab, setActiveTab] = useState<TabType>(`visual`);
  const [hasVisitedYaml, setHasVisitedYaml] = useState(false);
  const { state: { selectedAgentType, yamlPath } } = WorkflowSetup.Environment.useEnvironmentStore();
  const { state } = useContext(WorkflowSetup.Config.Context);

  if (!template) {
    return (
      <div className="flex items-center justify-center gray">
          Select a template to see the preview
      </div>
    );
  }

  const handleTabClick = (tab: TabType) => {
    if (tab === `yaml`) {
      setHasVisitedYaml(true);
    }
    setActiveTab(tab);
  };

  const getTemplateContent = () => {
    if (!template.template_content || !selectedAgentType) return ``;
    let content = template.template_content.replace(
      /type: \{\{ machine_type \}\}/g,
      `type: ${selectedAgentType.type}`
    );
    
    // Replace os_image template value
    const osImage = selectedAgentType.available_os_images?.length ? selectedAgentType.available_os_images[0] : `''`;

    content = content.replace(/\{\{ os_image \}\}/g, osImage);
    
    return content;
  };

  const handleSubmit = (e: Event, includeTemplate = true) => {
    e.preventDefault();
    
    if (!selectedAgentType || !state.workflowBuilderUrl) return;
    if (includeTemplate && !template) return;

    const form = document.createElement(`form`);
    form.method = `POST`;
    form.action = state.workflowBuilderUrl;

    const csrfInput = document.createElement(`input`);
    csrfInput.type = `hidden`;
    csrfInput.name = `_csrf_token`;
    csrfInput.value = state.csrfToken;
    form.appendChild(csrfInput);

    const fields = {
      machine_type: selectedAgentType.type,
      self_hosted_type: selectedAgentType.isSelfHosted,
      yaml_path: yamlPath,
      ...(includeTemplate && template ? {
        template_title: template.title,
        template_path: template.template_path,
      } : {})
    };

    Object.entries(fields).forEach(([name, value]) => {
      const input = document.createElement(`input`);
      input.type = `hidden`;
      input.name = name;
      input.value = String(value);
      form.appendChild(input);
    });

    document.body.appendChild(form);
    form.submit();
    document.body.removeChild(form);
  };

  return (
    <Fragment>
      <div className="flex items-start justify-between mb3">
        <div>
          <h2 className="f3 f2-m mb0">{template.title}</h2>
          <div className="gray measure-wide mb2" dangerouslySetInnerHTML={{
            __html: template.description,
          }}></div>
        </div>
        <toolbox.Asset path={`images/${template.icon}`} style={{ width: `28px` }} className="mb2"/>
      </div>

      <div className="flex items-center justify-between mb2" style="margin-top: -1rem; position: relative; z-index: 1;">
        <div className="flex button-group ml-auto">
          <button 
            className={`btn btn-small material-symbols-outlined f5 b ${activeTab === `visual` ? `btn-primary` : `btn-secondary`}`} 
            onClick={() => handleTabClick(`visual`)}
          >
            visibility
          </button>
          <Tippy
            placement="top"
            content="Check the code in the YAML view"
            trigger="mouseenter"
            visible={activeTab === `visual` && !hasVisitedYaml}>
            <button 
              className={`btn btn-small material-symbols-outlined f5 b ${activeTab === `yaml` ? `btn-primary` : `btn-secondary`}`}
              onClick={() => handleTabClick(`yaml`)}
            >
            code
            </button>
          </Tippy>
        </div>
      </div>

      <div className={`tab-content pa3 shadow-1 flex flex-column items-center justify-center ${activeTab !== `visual` ? `dn` : ``}`} style="min-height: 50vh; margin-top: -2rem;">
        <div id="blocks-container">
          <PipelinePreview yamlContent={getTemplateContent()} previewVisible={activeTab == `visual`}/>
        </div>
        <p className="pt3 mb0">
          <a href="#" onClick={(e) => handleSubmit(e)} className="mt3 mb1">Customize</a> this workflow, or <a href="#" onClick={(e) => handleSubmit(e, false)} className="mt3 mb1">Design from scratch</a>
        </p>
      </div>
              
      <div className={`tab-content pv3 shadow-1 ${activeTab !== `yaml` ? `dn` : ``}`} style="height: 50vh; margin-top: -2rem;">
        <Editor
          height="100%"
          defaultLanguage="yaml"
          value={getTemplateContent()}
          options={{
            minimap: { enabled: false },
            scrollBeyondLastLine: false,
            fontSize: 14,
            lineNumbers: `on`,
            renderLineHighlight: `none`,
            scrollbar: {
              vertical: `auto`,
              horizontal: `auto`,
            },
            readOnly: true,
          }}
          theme="vs-light"
        />
      </div>
    </Fragment>
  );
};
