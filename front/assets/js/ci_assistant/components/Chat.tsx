import { useReducer, useContext, useCallback, useEffect, useRef } from "preact/hooks";
import { Context as ConfigContext } from "../stores/config";
import { chatReducer, initialState, ChatAction } from "../stores/chat";
import { useWebSocket } from "../hooks/useWebSocket";
import { ConnectionStatus } from "./ConnectionStatus";
import { MessageList } from "./MessageList";
import { InputBar } from "./InputBar";
import { ModelSelector } from "./ModelSelector";

export function Chat() {
  const config = useContext(ConfigContext);
  const [state, dispatch] = useReducer(chatReducer, initialState);
  const modelsFetched = useRef(false);

  const stableDispatch = useCallback(
    (action: ChatAction) => dispatch(action),
    [],
  );

  const { sendMessage, sendCommand } = useWebSocket(
    config.hmacToken,
    stableDispatch,
  );

  // Fetch available models once on first connect
  useEffect(() => {
    if (state.connectionStatus === "connected" && !modelsFetched.current) {
      modelsFetched.current = true;
      sendCommand("/models");
    }
  }, [state.connectionStatus, sendCommand]);

  const handleSend = useCallback(
    (text: string) => {
      // Support slash commands from the input bar
      if (text.startsWith("/")) {
        sendCommand(text);
        return;
      }
      dispatch({ type: "MESSAGE", role: "user", content: text });
      sendMessage(text);
    },
    [sendMessage, sendCommand],
  );

  const handleModelSelect = useCallback(
    (model: string) => {
      sendCommand(`/model ${model}`);
    },
    [sendCommand],
  );

  const handleModelsRefresh = useCallback(() => {
    sendCommand("/models");
  }, [sendCommand]);

  const isDisconnected =
    state.connectionStatus === "disconnected" ||
    state.connectionStatus === "connecting";

  return (
    <div class="flex flex-column bg-white" style="height: calc(100vh - 120px); min-height: 400px">
      <div class="pa3 bb b--light-gray flex items-center justify-between">
        <h2 class="f5 fw6 ma0">CI Assistant</h2>
        <ModelSelector
          activeModel={state.activeModel}
          availableModels={state.availableModels}
          onSelect={handleModelSelect}
          onRefresh={handleModelsRefresh}
        />
      </div>
      <ConnectionStatus status={state.connectionStatus} />
      <MessageList
        timeline={state.timeline}
        isThinking={state.isThinking}
      />
      <InputBar onSend={handleSend} disabled={isDisconnected} />
    </div>
  );
}
