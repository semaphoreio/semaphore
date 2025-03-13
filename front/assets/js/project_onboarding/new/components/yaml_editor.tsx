import { forwardRef, useImperativeHandle, useRef } from "preact/compat";
import Editor from '@monaco-editor/react';
import { editor } from 'monaco-editor';

interface YamlEditorProps {
  value: string;
  onChange?: (value: string) => void;
  height?: string;
  readOnly?: boolean;
}

export const YamlEditor = forwardRef<any, YamlEditorProps>(({ value, onChange, height, readOnly = false }, ref) => {
  const monacoRef = useRef<editor.IStandaloneCodeEditor | null>(null);

  const handleEditorChange = (value: string | undefined) => {
    if (onChange && value) {
      onChange(value);
    }
  };

  const handleEditorDidMount = (editorInstance: editor.IStandaloneCodeEditor) => {
    monacoRef.current = editorInstance;
  };

  // Expose monaco editor instance via ref
  useImperativeHandle(ref, () => monacoRef.current);

  return (
    <div className="br3 bg-white shadow-1 mt2 pa3">
      <Editor
        height={height}
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
        onMount={(editorInstance) => handleEditorDidMount(editorInstance)}
      />
    </div>
  );
});
