import { render } from "preact";
import type { AppConfig } from "./app";
import { App } from "./app";

export default function ({ dom, config }: { dom: HTMLElement, config: AppConfig }) {
  render(<App config={config}/>, dom);
}
