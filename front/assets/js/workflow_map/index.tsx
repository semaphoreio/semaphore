import { render } from "preact";
import { useEffect } from "preact/hooks";
import { effect } from "@preact/signals";
import { Config, focusOn, loadError, now, refresh, resetState, selected, workflow } from "./store";
import { initLayout } from "./layout";
import { MapCanvas, aim, openBlocks, openPipelines } from "./map";
import { Toolbar } from "./toolbar";

export interface SelectedPipeline {
  id: string;
  switchId: string | null;
}

const App = ({ config, onSelect }: { config: Config, onSelect: (p: SelectedPipeline) => void, }) => {
  useEffect(() => {
    let stopped = false;
    let timer: number;
    const loop = async () => {
      try {
        if (!document.hidden) await refresh(config);
      } finally {
        if (!stopped) timer = window.setTimeout(() => void loop(), config.pollInterval);
      }
    };
    void loop();
    const clock = window.setInterval(() => (now.value = Math.floor(Date.now() / 1000)), 1000);

    let last = ``;
    const stopSync = effect(() => {
      const p = workflow.value?.pipelineById.get(selected.value);
      if (!p || `${p.id}:${p.switchId}` === last) return;
      last = `${p.id}:${p.switchId}`;
      onSelect({ id: p.id, switchId: p.switchId });
    });

    return () => {
      stopped = true;
      window.clearTimeout(timer);
      window.clearInterval(clock);
      stopSync();
    };
  }, []);

  return (
    <div className="wf-map-app">
      <Toolbar/>
      {loadError.value && <div className="wf-map-alert">{loadError.value}</div>}
      <div className="wf-map-canvas">
        <MapCanvas/>
      </div>
    </div>
  );
};

export default function WorkflowMap({ dom, config, onSelect }: { dom: HTMLElement, config: Config, onSelect: (p: SelectedPipeline) => void, }) {
  initLayout(config.elkWorkerUrl, () => {
    loadError.value = `Couldn't start the map's layout engine. Reload the page to try again.`;
  });
  resetState(config.selectedPipelineId);
  openPipelines.value = new Set([config.selectedPipelineId]);
  aim({ id: config.selectedPipelineId, how: `fit` });
  openBlocks.value = new Set();
  render(<App config={config} onSelect={onSelect}/>, dom);
}

export const selectPipeline = (id: string) => focusOn(`pipeline`, id);
