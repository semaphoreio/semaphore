interface Props {
  activeModel: string;
  availableModels: string[];
  onSelect: (model: string) => void;
  onRefresh: () => void;
}

export function ModelSelector({ activeModel, availableModels, onSelect, onRefresh }: Props) {
  if (availableModels.length === 0) {
    return (
      <button
        class="f7 gray bg-transparent bn pointer underline-hover"
        onClick={onRefresh}
        title="Load available models"
      >
        models
      </button>
    );
  }

  return (
    <select
      class="f7 bn bg-transparent gray pointer outline-0"
      value={activeModel}
      onChange={(e) => onSelect((e.target as HTMLSelectElement).value)}
      title="Switch model"
    >
      {availableModels.map((m) => (
        <option key={m} value={m}>{m}</option>
      ))}
    </select>
  );
}
