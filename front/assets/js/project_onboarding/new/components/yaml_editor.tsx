
import { forwardRef } from "preact/compat";
import Editor from '@monaco-editor/react';

interface YamlEditorProps {
  value: string;
  onChange?: (value: string) => void;
  readOnly?: boolean;
}

export const YamlEditor = forwardRef<any, YamlEditorProps>(({ value, onChange, readOnly = false }, ref) => {
  const handleEditorChange = (value: string | undefined) => {
    if (onChange && value) {
      onChange(value);
    }
  };

  return (
    <div className="br3 bg-white shadow-1 mt2 pa3">
      <Editor
        height="208px"
        ref={ref}
        defaultLanguage="yaml"
        value={value}
        onChange={handleEditorChange}
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
