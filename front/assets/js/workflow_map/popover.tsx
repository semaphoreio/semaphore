import DOMPurify from "dompurify";
import { useEffect } from "preact/hooks";
import { Pipeline } from "./model";
import { Promotions } from "./promote";
import { popover, workflow } from "./store";

const PipelineError = ({ p }: { p: Pipeline, }) => (
  <div className="wf-map-error-detail" role="dialog" aria-label={`Why ${p.name} failed to start`}>
    <div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(p.errorHtml) }}/>
    {p.initJob && (
      <a className="wf-map-error-log" href={p.initJob.url}>
        See the initialization log
      </a>
    )}
  </div>
);

export const Popover = () => {
  const open = popover.value;
  const p = open && workflow.value?.pipelineById.get(open.id);

  useEffect(() => {
    if (!open) return;
    const close = (e: Event) => {
      const outside = e instanceof KeyboardEvent ? e.key === `Escape` : !(e.target as Element).closest?.(`.wf-map-menu, [data-popover-trigger]`);
      if (outside) popover.value = null;
    };
    document.addEventListener(`pointerdown`, close);
    document.addEventListener(`keydown`, close);
    return () => {
      document.removeEventListener(`pointerdown`, close);
      document.removeEventListener(`keydown`, close);
    };
  }, [open?.kind, open?.id]);

  if (!p || (open.kind === `promote` ? !p.promotions?.length : !p.errorHtml)) return null;
  const width = open.kind === `promote` ? 340 : 480;
  return (
    <div className="wf-map-menu" style={{ width, left: Math.min(open.x, window.innerWidth - width - 16), top: open.y, maxHeight: window.innerHeight - open.y - 16 }}>
      {open.kind === `promote` ? <Promotions p={p}/> : <PipelineError p={p}/>}
    </div>
  );
};
