import { render } from "preact";
import { useEffect, useRef } from "preact/hooks";
import { Config, loadError, now, onNudge, refresh, resetState, tree } from "./store";
import { initLayout } from "./layout";
import { MapCanvas, aim, openBlocks, openPipelines } from "./map";
import { PromoteDialog, PromoteMenu, promoteMenu, promoting } from "./promote";
import { Toolbar } from "./toolbar";

const MAX_POLL_RUNNING = 15000;
const MAX_POLL_DONE = 30000;

const App = ({ config }: { config: Config, }) => {
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
    let delay = config.pollInterval;
    const loop = async () => {
      window.clearTimeout(timer);
      if (running) {
        again = true;
        return;
      }
      running = true;
      let changed = false;
      try {
        if (!document.hidden) changed = await refresh(config);
      } finally {
        running = false;
        const max = tree.value?.pipelines.every((p) => p.state === `DONE`) ? MAX_POLL_DONE : MAX_POLL_RUNNING;
        delay = changed || again ? config.pollInterval : Math.min(delay * 2, max);
        if (!stopped) timer = window.setTimeout(() => void loop(), again ? 0 : delay);
        again = false;
      }
    };
    const wake = () => {
      if (document.hidden || delay === config.pollInterval) return;
      delay = config.pollInterval;
      void loop();
    };
    onNudge(() => {
      delay = config.pollInterval;
      void loop();
    });
    document.addEventListener(`visibilitychange`, wake);
    window.addEventListener(`focus`, wake);
    void loop();
    const clock = window.setInterval(() => (now.value = Math.floor(Date.now() / 1000)), 1000);

    return () => {
      stopped = true;
      onNudge(() => undefined);
      document.removeEventListener(`visibilitychange`, wake);
      window.removeEventListener(`focus`, wake);
      window.clearTimeout(timer);
      window.clearInterval(clock);
    };
  }, []);

  return (
    <div className="wf-map-app" ref={root}>
      <Toolbar/>
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
  render(<App config={config}/>, dom);
}
