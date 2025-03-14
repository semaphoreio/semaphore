import { forwardRef } from "preact/compat";
import Editor, { OnMount } from '@monaco-editor/react';

interface YamlEditorProps {
  value: string;
  onChange?: (value: string) => void;
  height?: string;
  readOnly?: boolean;
  onMount?: OnMount;
}

export const YamlEditor = forwardRef<any, YamlEditorProps>(({ value, onChange, height, onMount, readOnly = false }, ref) => {
  const handleEditorChange = (value: string | undefined) => {
    if (onChange && value) {
      onChange(value);
    }
  };

  return (
    <div className="br3 bg-white shadow-1 mt2 pa3">
      <Editor
        ref={ref}
        height={height}
        defaultLanguage="yaml"
        value={value}
        onChange={handleEditorChange}
        onMount={onMount}
        options={{
          minimap: { enabled: false },
          scrollBeyondLastLine: false,
          readOnly,
          fontSize: 14,
          lineNumbers: `on`,
          renderLineHighlight: `none`,
          scrollbar: {
            vertical: `auto`,
            horizontal: `auto`,
          },
        }}
      />
    </div>
  );
});
