import { useEffect, useRef, useCallback } from "preact/hooks";
import { Socket, Channel } from "phoenix";
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

export function usePhoenixChannel(
  socketToken: string,
  dispatch: (action: ChatAction) => void,
): { sendMessage: (text: string) => void; sendCommand: (cmd: string) => void } {
  const socketRef = useRef<Socket | null>(null);
  const channelRef = useRef<Channel | null>(null);

  useEffect(() => {
    const socket = new Socket("/ci_assistant_socket", {
      params: { token: socketToken },
    });
    socket.connect();
    socketRef.current = socket;

    const channel = socket.channel("ci_assistant:lobby", {});
    channelRef.current = channel;

    channel.on("gateway_message", ({ envelope }: { envelope: string }) => {
      try {
        const env: Envelope = JSON.parse(envelope);
        handleEnvelope(env, dispatch);
      } catch {
        // ignore malformed messages
      }
    });

    channel
      .join()
      .receive("ok", () => {
        dispatch({ type: "CONNECTED" });
      })
      .receive("error", () => {
        dispatch({ type: "DISCONNECTED" });
      });

    channel.onClose(() => {
      dispatch({ type: "DISCONNECTED" });
    });

    channel.onError(() => {
      dispatch({ type: "RECONNECTING" });
    });

    return () => {
      channel.leave();
      socket.disconnect();
    };
  }, [socketToken, dispatch]);

  const sendMessage = useCallback((text: string) => {
    const channel = channelRef.current;
    if (channel) {
      const env: Envelope = {
        type: TypeUserMessage,
        timestamp: new Date().toISOString(),
        userMessage: { content: text },
      };
      channel.push("message", { envelope: JSON.stringify(env) });
    }
  }, []);

  const sendCommand = useCallback((command: string) => {
    const channel = channelRef.current;
    if (channel) {
      const env: Envelope = {
        type: TypeUserCommand,
        timestamp: new Date().toISOString(),
        userCommand: { command },
      };
      channel.push("message", { envelope: JSON.stringify(env) });
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
