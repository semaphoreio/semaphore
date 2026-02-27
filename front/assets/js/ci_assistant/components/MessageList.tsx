import { useRef, useEffect } from "preact/hooks";
import { TimelineEntry } from "../types";
import { Message } from "./Message";
import { ToolStatus } from "./ToolStatus";
import { ThinkingIndicator } from "./ThinkingIndicator";

interface Props {
  timeline: TimelineEntry[];
  isThinking: boolean;
}

export function MessageList({ timeline, isThinking }: Props) {
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [timeline.length, isThinking]);

  return (
    <div class="flex-auto overflow-y-auto pa3 flex flex-column" style="min-height: 0">
      {timeline.length === 0 && !isThinking && (
        <div class="flex-auto flex items-center justify-center gray f6">
          Ask a question about your CI/CD pipelines, workflows, or jobs.
        </div>
      )}
      {timeline.map((entry) => {
        if (entry.kind === "message") {
          return <Message key={entry.id} entry={entry} />;
        }
        return <ToolStatus key={entry.id} entry={entry} />;
      })}
      {isThinking && <ThinkingIndicator />}
      <div ref={bottomRef} />
    </div>
  );
}
