import { render } from "preact";
import { CreateApp } from "./create";
import { WorkflowSetupApp } from "./workflow_setup";
import { BrowserRouter } from "react-router-dom";
import * as stores from "./stores";

export function ProjectOnboardingCreate({ config, dom }: { dom: HTMLElement, config: stores.Create.Config.State }) {
  const ConfigProvider = ({ config, children }: { config: stores.Create.Config.State, children: any }) => {
    const csrfToken = document.querySelector(`meta[name="csrf-token"]`)?.getAttribute(`content`) || ``;
    const configStore = {
      csrfToken,
      ...config,
    };

    return (
      <stores.Create.Config.Context.Provider value={configStore}>
        {children}
      </stores.Create.Config.Context.Provider>
    );
  };

  render(
    <BrowserRouter basename={config.baseUrl}>
      <ConfigProvider config={config}>
        <CreateApp/>
      </ConfigProvider>
    </BrowserRouter>,
    dom
  );
}


export function ProjectOnboardingWorkflowSetup({ config, dom }: { dom: HTMLElement, config: stores.WorkflowSetup.Config.Config }) {
  const csrfToken = document.querySelector(`meta[name="csrf-token"]`)?.getAttribute(`content`) || ``;
  const configStore = {
    state: {
      csrfToken,
      ...config,
    },
  };

  render(
    <BrowserRouter basename={config.baseUrl}>
      <stores.WorkflowSetup.Config.Context.Provider value={configStore}>
        <WorkflowSetupApp/>
      </stores.WorkflowSetup.Config.Context.Provider>
    </BrowserRouter>
    ,
    dom
  );
}
