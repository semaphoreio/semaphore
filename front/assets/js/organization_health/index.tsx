import { render } from "preact";
import { App } from "./app";

export default function ({ dom, config }: { dom: HTMLElement, config: any }) {
  render(
    <App config={config}/>,
    dom);
}
