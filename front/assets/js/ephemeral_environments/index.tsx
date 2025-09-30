import { render } from "preact";
import { BrowserRouter } from "react-router-dom";
import { AppConfig, ConfigContext } from "./contexts/ConfigContext";
import { ProjectsProvider } from "./contexts/ProjectsContext";
import { App } from "./app";

export default function ({
  dom,
  config: jsonConfig,
}: {
  dom: HTMLElement;
  config: any;
}) {
  const appConfig = AppConfig.fromJSON(jsonConfig);

  render(
    <ConfigContext.Provider value={appConfig}>
      <ProjectsProvider config={appConfig}>
        <BrowserRouter basename={appConfig.baseUrl}>
          <App/>
        </BrowserRouter>
      </ProjectsProvider>
    </ConfigContext.Provider>,
    dom
  );
}
