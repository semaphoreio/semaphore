import { forwardRef, useImperativeHandle, useRef, useState } from "preact/compat";
import Editor, { Monaco } from '@monaco-editor/react';
import { editor } from 'monaco-editor';

interface YamlEditorProps {
  value: string;
  onChange?: (value: string) => void;
  height?: string;
  readOnly?: boolean;
}

interface MonacoInstances {
  editor: editor.IStandaloneCodeEditor | null;
  monaco: Monaco;
}

export const YamlEditor = forwardRef<any, YamlEditorProps>(({ value, onChange, height, readOnly = false }, ref) => {
  const [isMounted, setIsMounted] = useState(false);
  const monacoRef = useRef<MonacoInstances>(null);

  const handleEditorChange = (value: string | undefined) => {
    if (onChange && value) {
      onChange(value);
    }
  };

  const handleEditorDidMount = (editorInstance: editor.IStandaloneCodeEditor, monaco: Monaco) => {
    monacoRef.current = { editor: editorInstance, monaco: monaco };
    setIsMounted(true);
  };

  useImperativeHandle(ref, () => monacoRef.current, [isMounted]);

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
        onMount={handleEditorDidMount}
      />
    </div>
  );
});
