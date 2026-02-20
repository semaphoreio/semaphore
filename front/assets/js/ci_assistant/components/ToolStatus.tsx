import { TimelineEntry } from "../types";

interface Props {
  entry: Extract<TimelineEntry, { kind: "tool" }>;
}

function formatToolName(name: string): string {
  return name.replace(/_/g, " ");
}

export function ToolStatus({ entry }: Props) {
  const isRunning = entry.status === "running";
  const isDone = entry.status === "done";

  const icon = isRunning ? "\u25B6" : isDone ? "\u2713" : "\u2717";
  const color = isRunning ? "blue" : isDone ? "green" : "dark-red";

  return (
    <div class={`f7 ${color} pv1 ph2 flex items-center`}>
      <span class="mr1">{icon}</span>
      <span class="fw5">{formatToolName(entry.toolName)}</span>
      {entry.input && <span class="ml1 gray">{entry.input}</span>}
      {entry.error && <span class="ml1 dark-red i">{entry.error}</span>}
    </div>
  );
}
