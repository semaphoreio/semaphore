import { marked } from "marked";
import DOMPurify from "dompurify";
import { TimelineEntry } from "../types";

interface Props {
  entry: Extract<TimelineEntry, { kind: "message" }>;
}

function renderMarkdown(content: string): string {
  const raw = marked.parse(content, { async: false }) as string;
  return DOMPurify.sanitize(raw);
}

export function Message({ entry }: Props) {
  const isUser = entry.role === "user";
  const isSystem = entry.role === "system";

  if (isUser) {
    return (
      <div class="flex justify-end mb2">
        <div class="mw6 pa2 ph3 br3 bg-lightest-blue f6 lh-copy">
          {entry.content}
        </div>
      </div>
    );
  }

  if (isSystem) {
    return (
      <div class="mb2">
        <div class="pa2 ph3 br2 bg-washed-yellow f7 lh-copy gray"
             dangerouslySetInnerHTML={{ __html: renderMarkdown(entry.content) }} />
      </div>
    );
  }

  // assistant
  return (
    <div class="mb2">
      <div class="pa2 f6 lh-copy"
           dangerouslySetInnerHTML={{ __html: renderMarkdown(entry.content) }} />
    </div>
  );
}
