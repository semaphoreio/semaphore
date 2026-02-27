import { render } from "preact";
import { Context as ConfigContext, CiAssistantConfig } from "./stores/config";
import { Chat } from "./components/Chat";

export default function ({ dom, config }: { dom: HTMLElement; config: CiAssistantConfig }) {
  render(
    <ConfigContext.Provider value={config}>
      <Chat />
    </ConfigContext.Provider>,
    dom,
  );
}
