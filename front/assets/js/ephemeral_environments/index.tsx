import { render } from "preact";
import { BrowserRouter } from "react-router-dom";
import { AppConfig, ConfigContext } from "./config";
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
    <BrowserRouter basename={appConfig.baseUrl}>
      <ConfigContext.Provider value={appConfig}>
        <App/>
      </ConfigContext.Provider>
    </BrowserRouter>,
    dom
  );
}
