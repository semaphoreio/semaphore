import { render } from "preact";
import { App } from "./app";
import * as Store from "./store";

export default function ({ dom, config }: { dom: HTMLElement, config: any }) {
  render(
    <Store.Config.Context.Provider value={{ config }}>
      <App/>
    </Store.Config.Context.Provider>,
    dom
  );
}
