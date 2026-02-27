import { useEffect, useRef, useCallback } from "preact/hooks";
import {
  Envelope,
  TypeMessage,
  TypeTextDelta,
  TypeThinkingStart,
  TypeThinkingStop,
  TypeToolStart,
  TypeToolDone,
  TypeCommandResult,
  TypeSessionStart,
  TypeError,
  TypeUserMessage,
  TypeUserCommand,
} from "../types";
import { ChatAction } from "../stores/chat";

const RECONNECT_BASE_MS = 1000;
const RECONNECT_MAX_MS = 30000;

export function useWebSocket(
  gatewayWsUrl: string,
  hmacToken: string,
  dispatch: (action: ChatAction) => void,
): { sendMessage: (text: string) => void; sendCommand: (cmd: string) => void } {
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reconnectDelay = useRef(RECONNECT_BASE_MS);
  const tokenRef = useRef(hmacToken);

  // Keep token ref current so reconnects use latest token
  tokenRef.current = hmacToken;

  useEffect(() => {
    let disposed = false;

    function connect() {
      if (disposed) return;

      dispatch({ type: "RECONNECTING" });

      const url = `${gatewayWsUrl}?hmac_token=${encodeURIComponent(tokenRef.current)}`;
      const ws = new WebSocket(url);
      wsRef.current = ws;

      ws.onopen = () => {
        reconnectDelay.current = RECONNECT_BASE_MS;
        dispatch({ type: "CONNECTED" });
      };

      ws.onmessage = (event) => {
        try {
          const env: Envelope = JSON.parse(event.data);
          handleEnvelope(env, dispatch);
        } catch {
          // ignore malformed messages
        }
      };

      ws.onclose = () => {
        dispatch({ type: "DISCONNECTED" });
        scheduleReconnect();
      };

      ws.onerror = () => {
        // onclose will fire after this, which handles reconnect
      };
    }

    function scheduleReconnect() {
      if (disposed) return;
      const delay = reconnectDelay.current;
      reconnectDelay.current = Math.min(delay * 2, RECONNECT_MAX_MS);
      reconnectTimer.current = setTimeout(() => {
        fetchFreshToken().then(connect);
      }, delay);
    }

    async function fetchFreshToken() {
      try {
        const resp = await fetch("/ci_assistant/api/token");
        if (resp.ok) {
          const data = await resp.json();
          tokenRef.current = data.token;
        }
      } catch {
        // keep existing token
      }
    }

    connect();

    return () => {
      disposed = true;
      if (reconnectTimer.current) clearTimeout(reconnectTimer.current);
      if (wsRef.current) wsRef.current.close();
    };
  }, [gatewayWsUrl, dispatch]);

  const sendMessage = useCallback((text: string) => {
    const ws = wsRef.current;
    if (ws && ws.readyState === WebSocket.OPEN) {
      const env: Envelope = {
        type: TypeUserMessage,
        timestamp: new Date().toISOString(),
        userMessage: { content: text },
      };
      ws.send(JSON.stringify(env));
    }
  }, []);

  const sendCommand = useCallback((command: string) => {
    const ws = wsRef.current;
    if (ws && ws.readyState === WebSocket.OPEN) {
      const env: Envelope = {
        type: TypeUserCommand,
        timestamp: new Date().toISOString(),
        userCommand: { command },
      };
      ws.send(JSON.stringify(env));
    }
  }, []);

  return { sendMessage, sendCommand };
}

function handleEnvelope(env: Envelope, dispatch: (action: ChatAction) => void) {
  switch (env.type) {
    case TypeMessage:
      if (env.message) {
        dispatch({
          type: "MESSAGE",
          role: env.message.role as "user" | "assistant" | "system",
          content: env.message.content,
        });
      }
      break;

    case TypeTextDelta:
      if (env.textDelta) {
        dispatch({ type: "TEXT_DELTA", text: env.textDelta.text });
      }
      break;

    case TypeThinkingStart:
      dispatch({ type: "THINKING_START" });
      break;

    case TypeThinkingStop:
      dispatch({ type: "THINKING_STOP" });
      break;

    case TypeToolStart:
      if (env.toolStart) {
        dispatch({
          type: "TOOL_START",
          toolId: env.toolStart.toolId,
          toolName: env.toolStart.toolName,
          input: env.toolStart.input,
        });
      }
      break;

    case TypeToolDone:
      if (env.toolDone) {
        dispatch({
          type: "TOOL_DONE",
          toolId: env.toolDone.toolId,
          toolName: env.toolDone.toolName,
          error: env.toolDone.error,
        });
      }
      break;

    case TypeSessionStart:
      if (env.sessionStart) {
        dispatch({
          type: "SESSION_START",
          items: env.sessionStart.historyItems || [],
        });
      }
      break;

    case TypeCommandResult:
      if (env.commandResult) {
        dispatch({
          type: "COMMAND_RESULT",
          command: env.commandResult.command,
          result: env.commandResult.result,
        });
      }
      break;

    case TypeError:
      if (env.error) {
        dispatch({ type: "ERROR", message: env.error.message });
      }
      break;
  }
}
