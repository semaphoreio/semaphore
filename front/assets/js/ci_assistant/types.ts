/**
 * Wire protocol types mirroring pkg/wire/wire.go
 */

// Envelope types — server to client
export const TypeMessage = "message";
export const TypeTextDelta = "text.delta";
export const TypeThinkingStart = "thinking.start";
export const TypeThinkingStop = "thinking.stop";
export const TypeToolStart = "tool.start";
export const TypeToolDone = "tool.done";
export const TypeCommandResult = "command.result";
export const TypeSessionStart = "session.start";
export const TypeSessionEnd = "session.end";
export const TypeError = "error";

// Envelope types — client to server
export const TypeUserMessage = "user.message";
export const TypeUserCommand = "user.command";

export interface Envelope {
  type: string;
  timestamp: string;
  sessionId?: string;
  channelId?: string;
  message?: { role: string; content: string };
  textDelta?: { text: string };
  toolStart?: { toolId: string; toolName: string; input?: string; startedAt: string };
  toolDone?: { toolId: string; toolName: string; result?: string; error?: string };
  commandResult?: { command: string; result: string };
  error?: { message: string };
  userMessage?: { content: string };
  userCommand?: { command: string };
}

// Unified timeline entry — messages, tools, and system events all go here
export type TimelineEntry =
  | { kind: "message"; id: string; role: "user" | "assistant" | "system"; content: string }
  | { kind: "tool"; id: string; toolId: string; toolName: string; input?: string; status: "running" | "done" | "error"; error?: string };

export type ConnectionStatus = "connecting" | "connected" | "disconnected" | "reconnecting";
