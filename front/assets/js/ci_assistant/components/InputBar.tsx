import { useState, useRef } from "preact/hooks";

interface Props {
  onSend: (text: string) => void;
  disabled: boolean;
}

export function InputBar({ onSend, disabled }: Props) {
  const [text, setText] = useState("");
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const handleSubmit = () => {
    const trimmed = text.trim();
    if (!trimmed) return;
    onSend(trimmed);
    setText("");
    if (textareaRef.current) {
      textareaRef.current.style.height = "auto";
    }
  };

  const handleKeyDown = (e: KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSubmit();
    }
  };

  const handleInput = (e: Event) => {
    const target = e.target as HTMLTextAreaElement;
    setText(target.value);
    // Auto-resize
    target.style.height = "auto";
    target.style.height = Math.min(target.scrollHeight, 120) + "px";
  };

  return (
    <div class="pa3 bt b--light-gray flex items-end">
      <textarea
        ref={textareaRef}
        class="flex-auto bn outline-0 f6 lh-copy pa2 br2 bg-near-white resize-none"
        placeholder="Ask about your CI/CD..."
        rows={1}
        value={text}
        onInput={handleInput}
        onKeyDown={handleKeyDown}
        disabled={disabled}
      />
      <button
        class="ml2 ph3 pv2 bn br2 bg-blue white f6 pointer dim"
        onClick={handleSubmit}
        disabled={disabled || !text.trim()}
      >
        Send
      </button>
    </div>
  );
}
