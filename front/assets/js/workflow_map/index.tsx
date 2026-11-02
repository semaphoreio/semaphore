import { render } from "preact";
import { useEffect, useRef } from "preact/hooks";
import { effect } from "@preact/signals";
import { Config, ensureSelection, layoutError, loadError, now, onNudge, refresh, resetState, selected, tree, writePipelineId } from "./store";
import { initLayout } from "./layout";
import { MapCanvas, aim, openBlocks, openPipelines } from "./map";
import { Popover } from "./popover";
import { PromoteDialog, promoting } from "./promote";
import { Toolbar } from "./toolbar";
import { bindTooltips } from "./tooltips";

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
    const el = root.current;
    const bind = () => bindTooltips(el, (window as unknown as { tippy?: Parameters<typeof bindTooltips>[1], }).tippy);
    const observer = new MutationObserver(() => window.requestAnimationFrame(bind));
    observer.observe(el, { childList: true, subtree: true, attributes: true, attributeFilter: [`data-tippy-content`] });
    bind();
    return () => observer.disconnect();
  }, []);

  useEffect(
    () => effect(() => writePipelineId(selected.value, tree.value?.root_pipeline_id ?? ``, window.location, window.history)),
    [],
  );

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
        if (!document.hidden) changed = await refresh(config, openPipelines.peek());
        const root = ensureSelection();
        if (root) {
          openPipelines.value = new Set([root]);
          aim({ id: root, how: `fit` });
        }
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
    const poke = () => {
      delay = config.pollInterval;
      void loop();
    };
    onNudge(poke);
    let opened = openPipelines.peek();
    const watchOpened = effect(() => {
      const next = openPipelines.value;
      const added = [...next].some((id) => !opened.has(id));
      opened = next;
      if (added) poke();
    });
    document.addEventListener(`visibilitychange`, wake);
    window.addEventListener(`focus`, wake);
    void loop();
    const clock = window.setInterval(() => (now.value = Math.floor(Date.now() / 1000)), 1000);

    return () => {
      stopped = true;
      watchOpened();
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
      {(layoutError.value ?? loadError.value) && <div className="wf-map-alert">{layoutError.value ?? loadError.value}</div>}
      <div className="wf-map-canvas">
        <MapCanvas/>
      </div>
      <Popover/>
      <PromoteDialog/>
    </div>
  );
};

export default function WorkflowMap({ dom, config }: { dom: HTMLElement, config: Config, }) {
  initLayout(config.elkWorkerUrl, () => {
    layoutError.value = `Couldn't start the map's layout engine. Reload the page to try again.`;
  });
  resetState(config.selectedPipelineId);
  promoting.value = null;
  openPipelines.value = new Set([config.selectedPipelineId]);
  aim({ id: config.selectedPipelineId, how: `fit` });
  openBlocks.value = new Set();
  render(<App config={config}/>, dom);
}
