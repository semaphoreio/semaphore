import { render } from "preact";
import { App } from "./app";

import * as stores from "./stores";
import { BrowserRouter } from "react-router-dom";

export default function ({ dom, config, }: { dom: HTMLElement, config: any, }) {
  render(
    <BrowserRouter basename={config.baseURL}>
      <stores.Config.Context.Provider value={config}>
        <App/>
      </stores.Config.Context.Provider>
    </BrowserRouter>
    , dom
  );
}
