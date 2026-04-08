import { TimelineEntry, ConnectionStatus } from "../types";

export interface ChatState {
  timeline: TimelineEntry[];
  isThinking: boolean;
  streamBuffer: string;
  connectionStatus: ConnectionStatus;
  activeModel: string;
  availableModels: string[];
}

export const initialState: ChatState = {
  timeline: [],
  isThinking: false,
  streamBuffer: "",
  connectionStatus: "connecting",
  activeModel: "",
  availableModels: [],
};

export type ChatAction =
  | { type: "CONNECTED" }
  | { type: "DISCONNECTED" }
  | { type: "RECONNECTING" }
  | { type: "MESSAGE"; role: "user" | "assistant" | "system"; content: string }
  | { type: "TEXT_DELTA"; text: string }
  | { type: "THINKING_START" }
  | { type: "THINKING_STOP" }
  | { type: "TOOL_START"; toolId: string; toolName: string; input?: string }
  | { type: "TOOL_DONE"; toolId: string; toolName: string; error?: string }
  | { type: "COMMAND_RESULT"; command: string; result: string }
  | { type: "SESSION_START"; items: Array<{ role: string; content: string; toolName?: string; createdAt: string }> }
  | { type: "ERROR"; message: string }
  | { type: "SET_MODEL"; model: string }
  | { type: "CLEAR" };

let nextId = 0;
function genId(): string {
  return `e-${++nextId}`;
}

export function chatReducer(state: ChatState, action: ChatAction): ChatState {
  switch (action.type) {
    case "CONNECTED":
      return { ...state, connectionStatus: "connected" };

    case "DISCONNECTED":
      return { ...state, connectionStatus: "disconnected" };

    case "RECONNECTING":
      return { ...state, connectionStatus: "reconnecting" };

    case "MESSAGE": {
      const entry: TimelineEntry = {
        kind: "message",
        id: genId(),
        role: action.role,
        content: action.content,
      };
      return { ...state, timeline: [...state.timeline, entry] };
    }

    case "TEXT_DELTA": {
      const newBuffer = state.streamBuffer + action.text;
      const tl = [...state.timeline];
      const last = tl[tl.length - 1];

      if (last && last.kind === "message" && last.role === "assistant" && state.streamBuffer !== "") {
        tl[tl.length - 1] = { ...last, content: newBuffer };
      } else {
        tl.push({ kind: "message", id: genId(), role: "assistant", content: newBuffer });
      }

      return { ...state, timeline: tl, streamBuffer: newBuffer };
    }

    case "THINKING_START":
      return { ...state, isThinking: true, streamBuffer: "" };

    case "THINKING_STOP":
      return { ...state, isThinking: false, streamBuffer: "" };

    case "TOOL_START": {
      const entry: TimelineEntry = {
        kind: "tool",
        id: genId(),
        toolId: action.toolId,
        toolName: action.toolName,
        input: action.input,
        status: "running",
      };
      return { ...state, timeline: [...state.timeline, entry] };
    }

    case "TOOL_DONE": {
      const tl = state.timeline.map((e) =>
        e.kind === "tool" && e.toolId === action.toolId
          ? { ...e, status: (action.error ? "error" : "done") as "done" | "error", error: action.error }
          : e,
      );
      return { ...state, timeline: tl };
    }

    case "SESSION_START": {
      // Server history only contains messages, not tool calls.
      // On reconnect, keep existing timeline to preserve tool call UI state.
      if (state.timeline.length > 0) {
        return state;
      }
      const entries: TimelineEntry[] = action.items.map((item) => ({
        kind: "message" as const,
        id: genId(),
        role: (item.role === "user" || item.role === "assistant" ? item.role : "system") as "user" | "assistant" | "system",
        content: item.content,
      }));
      return { ...state, timeline: entries };
    }

    case "COMMAND_RESULT": {
      // Parse /models response to populate available models
      let models = state.availableModels;
      let activeModel = state.activeModel;
      let silent = false;

      if (action.command === "/models") {
        if (action.result.includes("Available models:")) {
          models = [];
          for (const line of action.result.split("\n")) {
            const match = line.match(/^([* ]) (.+?) \((.+)\)$/);
            if (match) {
              models.push(match[2]);
              if (match[1] === "*") activeModel = match[2];
            }
          }
          // Don't show the raw model list in chat — it's in the selector
          silent = true;
        } else if (action.result.includes("No agent configuration")) {
          // Silently handle — nothing to show in the selector
          silent = true;
        }
      }

      // Parse /model switch response
      if (action.command.startsWith("/model ") && action.result.startsWith("Switched to ")) {
        const match = action.result.match(/^Switched to (.+?) \(/);
        if (match) activeModel = match[1];
        silent = true;
      }

      const timeline = silent
        ? state.timeline
        : [...state.timeline, { kind: "message" as const, id: genId(), role: "system" as const, content: action.result }];

      return { ...state, timeline, availableModels: models, activeModel };
    }

    case "SET_MODEL":
      return { ...state, activeModel: action.model };

    case "ERROR": {
      const entry: TimelineEntry = {
        kind: "message",
        id: genId(),
        role: "system",
        content: action.message,
      };
      return { ...state, timeline: [...state.timeline, entry] };
    }

    case "CLEAR":
      return { ...initialState, connectionStatus: state.connectionStatus, availableModels: state.availableModels, activeModel: state.activeModel };

    default:
      return state;
  }
}
