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

const MAX_RECONNECT_ATTEMPTS = 30;
const RECONNECT_INTERVAL_MS = 2000;

async function fetchFreshToken(): Promise<string | null> {
  try {
    const resp = await fetch("./api/token", { credentials: "same-origin" });
    if (!resp.ok) return null;
    const data = await resp.json();
    return data.hmacToken || null;
  } catch {
    return null;
  }
}

export function useWebSocket(
  wsUrl: string,
  hmacToken: string,
  dispatch: (action: ChatAction) => void,
): { sendMessage: (text: string) => void; sendCommand: (cmd: string) => void } {
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectAttempts = useRef(0);
  const reconnectTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const currentToken = useRef(hmacToken);

  const connectWithToken = useCallback((token: string) => {
    currentToken.current = token;
    const url = `${wsUrl}?hmac_token=${encodeURIComponent(token)}`;
    const ws = new WebSocket(url);
    wsRef.current = ws;

    ws.onopen = () => {
      reconnectAttempts.current = 0;
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
      attemptReconnect();
    };

    ws.onerror = () => {
      // onclose will fire after onerror
    };
  }, [wsUrl, dispatch]);

  const attemptReconnect = useCallback(() => {
    if (reconnectAttempts.current >= MAX_RECONNECT_ATTEMPTS) return;
    reconnectAttempts.current++;
    dispatch({ type: "RECONNECTING" });
    reconnectTimer.current = setTimeout(async () => {
      // Fetch a fresh HMAC token before reconnecting (the original one has a 60s TTL)
      const freshToken = await fetchFreshToken();
      connectWithToken(freshToken || currentToken.current);
    }, RECONNECT_INTERVAL_MS);
  }, [connectWithToken, dispatch]);

  useEffect(() => {
    connectWithToken(hmacToken);
    return () => {
      if (reconnectTimer.current) clearTimeout(reconnectTimer.current);
      if (wsRef.current) {
        wsRef.current.onclose = null; // prevent reconnect on intentional close
        wsRef.current.close();
      }
    };
  }, [connectWithToken, hmacToken]);

  const sendMessage = useCallback((text: string) => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      const env: Envelope = {
        type: TypeUserMessage,
        timestamp: new Date().toISOString(),
        userMessage: { content: text },
      };
      wsRef.current.send(JSON.stringify(env));
    }
  }, []);

  const sendCommand = useCallback((command: string) => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      const env: Envelope = {
        type: TypeUserCommand,
        timestamp: new Date().toISOString(),
        userCommand: { command },
      };
      wsRef.current.send(JSON.stringify(env));
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
