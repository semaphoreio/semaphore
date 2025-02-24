import { render } from "preact";
import { App, AppConfig } from "./app";

export default function ({ dom, config }: { dom: HTMLElement, config: AppConfig, }) {
  render(<App config={config}/>, dom);
}
