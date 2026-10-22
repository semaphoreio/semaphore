import { render } from "preact";
import { createPortal } from "preact/compat";
import { useEffect, useRef } from "preact/hooks";
import { Config, loadError, now, onNudge, refresh, resetState } from "./store";
import { initLayout } from "./layout";
import { MapCanvas, aim, openBlocks, openPipelines } from "./map";
import { PromoteDialog, PromoteMenu, promoteMenu, promoting } from "./promote";
import { Toolbar } from "./toolbar";

const App = ({ config, toolbarSlot }: { config: Config, toolbarSlot: HTMLElement | null, }) => {
  const root = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const fill = () => {
      const el = root.current;
      el.style.height = `${Math.max(480, window.innerHeight - window.scrollY - el.getBoundingClientRect().top)}px`;
    };
    fill();
    window.addEventListener(`resize`, fill);
    return () => window.removeEventListener(`resize`, fill);
  }, []);

  useEffect(() => {
    let stopped = false;
    let running = false;
    let again = false;
    let timer: number;
    const loop = async () => {
      window.clearTimeout(timer);
      if (running) {
        again = true;
        return;
      }
      running = true;
      try {
        if (!document.hidden) await refresh(config);
      } finally {
        running = false;
        if (!stopped) timer = window.setTimeout(() => void loop(), again ? 0 : config.pollInterval);
        again = false;
      }
    };
    onNudge(() => void loop());
    void loop();
    const clock = window.setInterval(() => (now.value = Math.floor(Date.now() / 1000)), 1000);

    return () => {
      stopped = true;
      onNudge(() => undefined);
      window.clearTimeout(timer);
      window.clearInterval(clock);
    };
  }, []);

  return (
    <div className="wf-map-app" ref={root}>
      {toolbarSlot ? createPortal(<Toolbar/>, toolbarSlot) : <Toolbar/>}
      {loadError.value && <div className="wf-map-alert">{loadError.value}</div>}
      <div className="wf-map-canvas">
        <MapCanvas/>
      </div>
      <PromoteMenu/>
      <PromoteDialog/>
    </div>
  );
};

export default function WorkflowMap({ dom, config }: { dom: HTMLElement, config: Config, }) {
  initLayout(config.elkWorkerUrl, () => {
    loadError.value = `Couldn't start the map's layout engine. Reload the page to try again.`;
  });
  resetState(config.selectedPipelineId);
  promoting.value = null;
  promoteMenu.value = null;
  openPipelines.value = new Set([config.selectedPipelineId]);
  aim({ id: config.selectedPipelineId, how: `fit` });
  openBlocks.value = new Set();
  render(<App config={config} toolbarSlot={document.getElementById(`wf-map-toolbar-slot`)}/>, dom);
}
