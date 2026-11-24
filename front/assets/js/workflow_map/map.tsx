import { useEffect, useMemo, useRef, useState } from "preact/hooks";
import { computed, signal } from "@preact/signals";
import { BaseEdge, Background, Controls, Edge, EdgeLabelRenderer, EdgeProps, Handle, MiniMap, Node, NodeProps, Panel, Position, ReactFlow, ReactFlowProvider, useReactFlow, useStore } from "@xyflow/react";
import { Block, InitJob, Pipeline, Workflow, blockStatus, pipelineJobs, plural, stopReason } from "./model";
import { focus, hits, layoutError, popover, rerunPipeline, selected, stopPipeline, togglePopover, workflow } from "./store";
import { MapLayout, Point, layoutMap, promotionLabel } from "./layout";
import { PromoteButton } from "./promote";
import { Chips, Search, Stepper } from "./toolbar";
import { BlockCard, BlockSummary, Chevron, Counts, Duration, Name, PipelineTitle, StatusBar, StatusIcon, StopDetails, StopReason, Triggered, plainClick } from "./ui";
import { blockSize, jobRow } from "./lines";

const CARD = { w: 300, h: 72 };

const CLICKABLE = { pointerEvents: `all` as const };

export const openPipelines = signal<Set<string>>(new Set());
export const openBlocks = signal<Set<string>>(new Set());
export const openDetails = signal<Set<string>>(new Set());
export const DETAILS_H = 48;
export const detailsBand = (p: Pipeline, open: Set<string>) => (open.has(p.id) && stopReason(p) ? DETAILS_H : 0);
const hovered = signal<string | null>(null);

const lineage = computed(() => {
  const start = hovered.value && workflow.value?.blocks.get(hovered.value);
  if (!start) return null;
  const chain = new Set<string>([start.id]);
  const up = (b: typeof start) =>
    b.deps.forEach((d) => {
      if (!chain.has(d.id)) chain.add(d.id), up(d);
    });
  const down = (b: typeof start) =>
    b.pipeline.blocks.forEach((next) => {
      if (next.deps.includes(b) && !chain.has(next.id)) chain.add(next.id), down(next);
    });
  up(start);
  down(start);
  return { chain, pipelineId: start.pipeline.id };
});

export interface Target { id: string, how: `fit` | `focus` | `all` | `keep` | `open`, job?: number, at?: Point, }
let target: Target | null = null;

const READABLE = 0.75;
const GLIDE_MS = 250;
const EDGE = 40;
const TOOLS = 64;

interface Box { x: number, y: number, w: number, h: number, }
export interface View { x: number, y: number, zoom: number, }

export function nextView(how: `fit` | `focus` | `keep` | `open`, box: Box, pad: number, v: View, vw: number, vh: number, at?: Point): View | null {
  if (how !== `fit` && how !== `focus`) {
    const kept = { x: v.x - (box.x - at.x) * v.zoom, y: v.y - (box.y - at.y) * v.zoom, zoom: v.zoom };
    if (how !== `open`) return kept;
    const into = (start: number, size: number, room: number) => {
      const end = start + size * v.zoom;
      return start < EDGE ? EDGE - start : end > room - EDGE ? Math.max(room - EDGE - end, EDGE - start) : 0;
    };
    return { x: kept.x + into(box.x * v.zoom + kept.x, box.w, vw), y: kept.y + into(box.y * v.zoom + kept.y, box.h, vh), zoom: v.zoom };
  }
  const fit = Math.max(0.1, Math.min(1, vw / (box.w * pad), vh / (box.h * pad)));
  const wide = Math.max(0.1, Math.min(1, vw / (box.w * pad)));
  const zoom = how === `fit` ? Math.max(fit, Math.min(wide, READABLE)) : Math.max(v.zoom, Math.min(READABLE, fit));
  const left = box.x * v.zoom + v.x;
  const top = box.y * v.zoom + v.y;
  const shown = left >= EDGE && top >= EDGE && left + box.w * v.zoom <= vw - EDGE && top + box.h * v.zoom <= vh - EDGE;
  if (how === `focus` && zoom === v.zoom && shown) return null;
  const place = (start: number, size: number, room: number, edge: number, slack: number) => (size * zoom > room - slack ? edge - start * zoom : room / 2 - (start + size / 2) * zoom);
  return { x: place(box.x, box.w, vw, EDGE, how === `focus` ? 2 * EDGE : 0), y: place(box.y, box.h, vh, TOOLS, 2 * TOOLS), zoom };
}

export function firstView(all: Box, root: Box, v: View, vw: number, vh: number): View {
  const whole = nextView(`fit`, all, 1.12, v, vw, vh);
  const zoom = Math.max(0.1, Math.min(READABLE, vw / (root.w * 1.12)));
  if (whole.zoom >= zoom) return whole;
  return { x: EDGE - root.x * zoom, y: TOOLS - root.y * zoom, zoom };
}

export const aim = (next: Target | null) => {
  target = next;
};

const toggle = (s: typeof openPipelines, id: string, on?: boolean) => {
  const next = new Set(s.value);
  (on ?? !next.has(id)) ? next.add(id) : next.delete(id);
  s.value = next;
};

const PipelineActions = ({ p, compact }: { p: Pipeline, compact?: boolean, }) => {
  const [busy, setBusy] = useState<`stop` | `rerun` | null>(null);
  if (!p.stopUrl && !p.rebuildUrl && !p.promotions?.length) return null;
  const run = async (kind: `stop` | `rerun`) => {
    setBusy(kind);
    const error = await (kind === `stop` ? stopPipeline(p) : rerunPipeline(p));
    setBusy(null);
    const notice = (window as unknown as { Notice?: { notice: (m: string) => void, error: (m: string) => void, }, }).Notice;
    if (error) notice?.error(error);
    else notice?.notice(kind === `stop` ? `${p.name} will be stopped shortly.` : `Rerunning the failed jobs of ${p.name}.`);
  };
  return (
    <span className="wf-map-actions" onClick={(e) => e.stopPropagation()} onKeyDown={(e) => e.stopPropagation()}>
      {p.stopUrl && (
        <button
          className="btn btn-secondary btn-tiny wf-map-outline wf-map-outline-red"
          disabled={busy !== null}
          aria-label={compact ? `Stop ${p.name}` : undefined}
          data-tippy-content="Stops this pipeline"
          onClick={() => void run(`stop`)}
        >
          {compact ? <span className="material-symbols-outlined" aria-hidden="true">stop</span> : busy === `stop` ? `Stopping…` : `Stop`}
        </button>
      )}
      {p.rebuildUrl && (
        <button
          className="btn btn-secondary btn-tiny wf-map-outline wf-map-outline-grey"
          disabled={busy !== null}
          aria-label={compact ? `Rerun the failed jobs of ${p.name}` : undefined}
          data-tippy-content="Reruns only the jobs in this pipeline that did not pass, keeping the ones that did"
          onClick={() => void run(`rerun`)}
        >
          {compact ? <span className="material-symbols-outlined" aria-hidden="true">replay</span> : busy === `rerun` ? `Rerunning…` : `Rerun failed`}
        </button>
      )}
      <PromoteButton p={p} compact={compact}/>
    </span>
  );
};

const CardNode = ({ data, positionAbsoluteX, positionAbsoluteY }: NodeProps<Node<{ id: string, }>>) => {
  const p = workflow.value?.pipelineById.get(data.id);
  const h = hits.value;
  if (!p) return null;
  const n = h.perPipeline.get(p) ?? 0;
  const jobs = pipelineJobs(p);
  const open = (card: Element) => {
    selected.value = p.id;
    if (p.errorHtml) return togglePopover(`error`, p.id, card);
    aim({ id: p.id, how: `open`, at: { x: positionAbsoluteX, y: positionAbsoluteY } });
    toggle(openPipelines, p.id, true);
  };
  return (
    <div
      role="button"
      tabIndex={0}
      data-popover-trigger={p.errorHtml ? `` : undefined}
      aria-expanded={p.errorHtml ? undefined : false}
      className={`wf-map-card ${p.status === `failed` ? `failed` : ``} ${selected.value === p.id ? `selected` : ``} ${h.active && !n ? `dim` : ``}`}
      onClick={(e) => plainClick(e, open)}
      onKeyDown={(e) => (e.key === `Enter` || e.key === ` `) && (e.preventDefault(), open(e.currentTarget))}
    >
      <Handle type="target" id="in" position={Position.Left} isConnectable={false}/>
      <span className="wf-map-card-row">
        {!p.errorHtml && <Chevron open={false}/>}
        <StatusIcon status={p.status} size={18}/>
        <span className="wf-map-card-title">
          <PipelineTitle p={p}/>
        </span>
        <PipelineActions p={p} compact/>
      </span>
      {p.blocks ? <StatusBar jobs={jobs}/> : <span className="wf-map-bar loading"/>}
      <span className="wf-map-card-row wf-map-card-meta">
        {p.errorHtml ? (
          <span className="wf-map-error">Pipeline failed to start · see why</span>
        ) : !p.blocks ? (
          <span>Loading blocks…</span>
        ) : !p.blocks.length && p.initJob ? (
          <span>
            {p.initJob.status === `running` || p.initJob.status === `pending` ? `Initializing` : `Initialization`} ·{` `}
            <a href={p.initJob.url} onClick={(e) => e.stopPropagation()}>
              log
            </a>
          </span>
        ) : stopReason(p) ? (
          <StopReason p={p}/>
        ) : (
          <span>
            {plural(p.blocks.length, `block`)} · {plural(jobs.length, `job`)}
          </span>
        )}
        <span className="wf-map-card-end">
          {h.active ? <span className={`wf-map-match ${n ? `` : `zero`}`}>{n} matching</span> : <Counts jobs={jobs}/>}
          <Duration start={p.runningAt} end={p.doneAt} running={p.status === `running`}/>
          {p.triggerer && <span className="wf-map-sep" aria-hidden="true"/>}
          <Triggered p={p}/>
        </span>
      </span>
      <Handle type="source" id="out" position={Position.Right} isConnectable={false}/>
    </div>
  );
};

export const AfterBand = ({ block, box, at }: { block: Block, box: Point, at: Point, }) => {
  const open = openBlocks.value.has(block.id);
  const h = hits.value;
  const flip = () => {
    aim({ id: block.pipeline.id, how: `keep`, at });
    toggle(openBlocks, block.id);
  };
  const { w, h: height } = blockSize(block, open);
  return (
    <div className={`wf-map-after ${h.active && !h.blocks.has(block) ? `dim` : ``}`} style={{ left: box.x, top: box.y, width: w, height }}>
      {open ? <BlockCard block={block} onHeaderClick={flip}/> : <BlockSummary block={block} onClick={flip}/>}
    </div>
  );
};

export const BlocksToggle = ({ pipelines, anchor }: { pipelines: Pipeline[], anchor: Target | null, }) => {
  const blocks = pipelines.flatMap((p) => p.blocks ?? []);
  const open = blocks.length > 0 && blocks.every((b) => openBlocks.value.has(b.id));
  return (
    <button
      className="btn btn-secondary btn-small wf-map-blocks-toggle"
      data-tippy-content={`${open ? `Collapses` : `Expands`} the blocks of every open pipeline`}
      disabled={blocks.length === 0}
      onClick={() => {
        aim(anchor);
        const next = new Set(openBlocks.value);
        blocks.forEach((b) => (open ? next.delete(b.id) : next.add(b.id)));
        openBlocks.value = next;
      }}
    >
      <span className="material-symbols-outlined" aria-hidden="true">{open ? `unfold_less` : `unfold_more`}</span>
      {open ? `Collapse all blocks` : `Expand all blocks`}
    </button>
  );
};

export const InitTab = ({ job }: { job: InitJob, }) => (
  <a className="wf-map-init-tab" href={job.url} data-tippy-content="Opens the initialization log" onClick={(e) => e.stopPropagation()}>
    <StatusIcon status={job.status} size={12}/>
    Initialization
    <Duration start={job.started_at} end={job.finished_at} running={job.status === `running`}/>
  </a>
);

const PipelineNode = ({ data, positionAbsoluteX, positionAbsoluteY }: NodeProps<Node<{ id: string, after?: Point, }>>) => {
  const p = workflow.value?.pipelineById.get(data.id);
  const h = hits.value;
  if (!p) return null;
  const after = p.blocks?.find((b) => b.after);
  const at = { x: positionAbsoluteX, y: positionAbsoluteY };
  return (
    <div className={`wf-map-pipeline ${selected.value === p.id ? `selected` : ``} ${h.active && !h.pipelines.has(p) ? `dim` : ``}`} onClick={(e) => plainClick(e, () => (selected.value = p.id))}>
      <Handle type="target" id="in" position={Position.Left} isConnectable={false} style={{ top: 34 }}/>
      <div className="wf-map-pipeline-head">
        <div className="wf-map-pipeline-row">
          <button
            className="wf-map-collapse"
            aria-label={`Collapse ${p.name}`}
            aria-expanded={true}
            onClick={(e) => {
              e.stopPropagation();
              aim({ id: p.id, how: `keep`, at });
              toggle(openPipelines, p.id, false);
            }}
          >
            <Chevron open/>
          </button>
          <StatusIcon status={p.status} size={18}/>
          <span className="wf-map-pipeline-title">
            <PipelineTitle p={p}/>
          </span>
          <Counts jobs={pipelineJobs(p)}/>
          <Duration start={p.runningAt} end={p.doneAt} running={p.status === `running`}/>
          {p.triggerer && <span className="wf-map-sep" aria-hidden="true"/>}
          <Triggered p={p}/>
        </div>
        <div className="wf-map-pipeline-row wf-map-pipeline-sub">
          <Name className="wf-map-pipeline-meta">{p.yamlFile}</Name>
          <StopReason
            p={p}
            open={openDetails.value.has(p.id)}
            onToggle={() => {
              aim({ id: p.id, how: `keep`, at });
              toggle(openDetails, p.id);
            }}
          />
          <PipelineActions p={p}/>
        </div>
      </div>
      {detailsBand(p, openDetails.value) > 0 && <StopDetails p={p}/>}
      {p.initJob && <InitTab job={p.initJob}/>}
      {after && data.after && <AfterBand block={after} box={data.after} at={at}/>}
      <Handle type="source" id="out" position={Position.Right} isConnectable={false} style={{ top: 34 }}/>
    </div>
  );
};

const BlockNode = ({ data, positionAbsoluteX, positionAbsoluteY }: NodeProps<Node<{ id: string, }>>) => {
  const b = workflow.value?.blocks.get(data.id);
  const h = hits.value;
  if (!b) return null;
  const flip = () => {
    aim({ id: b.id, how: `keep`, at: { x: positionAbsoluteX, y: positionAbsoluteY } });
    toggle(openBlocks, b.id);
  };
  const l = lineage.value;
  const inChain = l?.chain.has(b.id);
  return (
    <div
      className={`wf-map-node ${h.active && !h.blocks.has(b) ? `dim` : ``} ${inChain ? `lit` : l?.pipelineId === b.pipeline.id ? `faded` : ``} ${hovered.value === b.id ? `hovered` : ``}`}
      onMouseEnter={() => (hovered.value = b.id)}
      onMouseLeave={() => hovered.value === b.id && (hovered.value = null)}
    >
      <Handle type="target" position={Position.Left} isConnectable={false}/>
      {openBlocks.value.has(b.id) ? (
        <BlockCard block={b} onHeaderClick={flip}/>
      ) : (
        <BlockSummary block={b} onClick={flip}/>
      )}
      <Handle type="source" position={Position.Right} isConnectable={false}/>
    </div>
  );
};

function rounded(pts: Point[], r = 10) {
  if (pts.length < 2) return ``;
  let d = `M${pts[0].x},${pts[0].y}`;
  for (let i = 1; i < pts.length - 1; i++) {
    const [a, b, c] = [pts[i - 1], pts[i], pts[i + 1]];
    const r1 = Math.min(r, Math.hypot(b.x - a.x, b.y - a.y) / 2, Math.hypot(c.x - b.x, c.y - b.y) / 2);
    const toward = (to: Point) => {
      const len = Math.hypot(to.x - b.x, to.y - b.y) || 1;
      return { x: b.x + ((to.x - b.x) / len) * r1, y: b.y + ((to.y - b.y) / len) * r1 };
    };
    const p1 = toward(a);
    const p2 = toward(c);
    d += ` L${p1.x},${p1.y} Q${b.x},${b.y} ${p2.x},${p2.y}`;
  }
  const last = pts[pts.length - 1];
  return `${d} L${last.x},${last.y}`;
}

const flowing = (target: string) => {
  const wf = workflow.value;
  const b = wf?.blocks.get(target);
  const st = b ? blockStatus(b) : wf?.pipelineById.get(target)?.status;
  return st === `running` || st === `queued` || st === `failed` ? `wf-map-edge-${st}` : ``;
};

const RouteEdge = ({ id, data, source, target }: EdgeProps<Edge<{ points: Point[], label?: string, labelAt?: Point, }>>) => {
  const l = lineage.value;
  const state = !l || !source.startsWith(`${l.pipelineId}/`) ? `` : l.chain.has(source) && l.chain.has(target) ? `wf-map-edge-lit` : `wf-map-edge-faded`;
  return (
    <>
      <BaseEdge id={id} path={rounded(data.points)} className={`${state} ${flowing(target)}`}/>
      {data.label && data.labelAt && (
        <EdgeLabelRenderer>
          <div className="wf-map-edge-label" style={{ transform: `translate(-50%, -50%) translate(${data.labelAt.x}px, ${data.labelAt.y}px)` }}>
            <Name>{data.label}</Name>
          </div>
        </EdgeLabelRenderer>
      )}
    </>
  );
};

const nodeTypes = { card: CardNode, pipeline: PipelineNode, block: BlockNode };
const edgeTypes = { route: RouteEdge };

function build(wf: Workflow, L: MapLayout) {
  const nodes: Node[] = [];
  const edges: Edge[] = [];
  for (const p of wf.pipelines) {
    const box = L.pipelines.get(p.id);
    if (!box) continue;
    const after = p.blocks?.find((b) => b.after);
    nodes.push({ id: p.id, type: box.open ? `pipeline` : `card`, position: { x: box.x, y: box.y }, width: box.w, height: box.h, style: CLICKABLE, data: { id: p.id, after: after && L.blocks.get(after.id) }, draggable: false, selectable: false });
    if (box.open) {
      for (const b of p.blocks ?? []) {
        const bb = L.blocks.get(b.id);
        if (!bb || b.after) continue;
        nodes.push({ id: b.id, type: `block`, parentId: p.id, position: { x: bb.x, y: bb.y }, width: bb.w, height: bb.h, style: CLICKABLE, data: { id: b.id }, draggable: false, selectable: false });
        for (const d of b.deps) {
          const id = `${d.id}->${b.id}`;
          edges.push({ id, type: `route`, source: d.id, target: b.id, className: `dep`, focusable: false, data: { points: L.routes.get(id) ?? [] } });
        }
      }
    }
    if (p.parent && L.pipelines.has(p.parent.id)) {
      const kind = p.trigger === `AUTO_PROMOTION` ? `auto` : p.trigger === `PIPELINE_PARTIAL_RERUN` ? `rerun` : `manual`;
      const id = `${p.parent.id}=>${p.id}`;
      edges.push({
        id,
        type: `route`,
        source: p.parent.id,
        sourceHandle: `out`,
        target: p.id,
        targetHandle: `in`,
        className: `promo ${kind}`,
        focusable: false,
        data: { points: L.routes.get(id) ?? [], label: promotionLabel(p), labelAt: L.labels.get(id) },
      });
    }
  }
  return { nodes, edges };
}

export const SMALL_PIPELINE_JOBS = 20;

export function seedBlocks(pipelines: Pipeline[], open: Set<string>, seeded: Set<string>, blocks: Set<string>): Set<string> | null {
  let next: Set<string> | null = null;
  for (const p of pipelines) {
    if (!open.has(p.id) || !p.blocks?.length || seeded.has(p.id)) continue;
    seeded.add(p.id);
    const all = !p.done || pipelineJobs(p).length <= SMALL_PIPELINE_JOBS;
    for (const b of p.blocks) {
      if ((all || blockStatus(b) === `failed`) && !blocks.has(b.id)) (next ??= new Set(blocks)).add(b.id);
    }
  }
  return next;
}

export function structureKey(wf: Workflow, open: Set<string>, openB: Set<string>, details: Set<string> = new Set()) {
  return wf.pipelines
    .map((p) => {
      const blocks = open.has(p.id) && p.blocks ? p.blocks.map((b) => `${b.name}:${b.deps.length}:${openB.has(b.id) ? b.jobs.length : `-`}`).join(`,`) : `closed`;
      const promotions = p.promotions?.map((promotion) => `${promotion.name}:${promotion.pipelines.length}`).join(`,`) ?? ``;
      const after = p.blocks?.find((b) => b.after);
      return `${p.id}${p.initJob ? `+init` : ``}${detailsBand(p, details) ? `+details` : ``}<${p.parent?.id ?? ``}>${blocks}[${promotions}]${after ? `+${openB.has(after.id) ? after.jobs.length : `-`}` : ``}`;
    })
    .join(`|`);
}

function boxOf(wf: Workflow, L: MapLayout, id: string) {
  const pb = L.pipelines.get(id);
  if (pb) return pb;
  const block = wf.blocks.get(id);
  const p = block && L.pipelines.get(block.pipeline.id);
  const bb = L.blocks.get(id);
  return p && bb && { x: p.x + bb.x, y: p.y + bb.y, w: bb.w, h: bb.h };
}

const WorkflowMap = () => {
  const rf = useReactFlow();
  const wf = workflow.value;
  const P = openPipelines.value;
  const B = openBlocks.value;
  const D = openDetails.value;
  const f = focus.value;
  const h = hits.value;
  const zoom = useStore((s) => s.transform[2]);
  const vw = useStore((s) => s.width);
  const vh = useStore((s) => s.height);
  const [layout, setLayout] = useState<MapLayout | null>(null);
  const handledSeq = useRef(0);
  const seeded = useRef(new Set<string>());
  const key = wf ? structureKey(wf, P, B, D) : ``;

  useEffect(() => {
    const next = wf && seedBlocks(wf.pipelines, P, seeded.current, openBlocks.value);
    if (next) openBlocks.value = next;
  }, [wf, P]);

  const wholeBox = (L: MapLayout) => {
    const boxes = [...L.pipelines.values()];
    const x = Math.min(...boxes.map((b) => b.x));
    const y = Math.min(...boxes.map((b) => b.y));
    return { x, y, w: Math.max(...boxes.map((b) => b.x + b.w)) - x, h: Math.max(...boxes.map((b) => b.y + b.h)) - y };
  };
  const fitAll = (L: MapLayout) => {
    void rf.setViewport(nextView(`fit`, wholeBox(L), 1.12, rf.getViewport(), vw, vh));
  };

  const go = (L: MapLayout, t: Target) => {
    if (!vw || !vh) return false;
    const p = wf.pipelineById.get(t.id);
    if (t.how === `all` || (!p && !wf.blocks.has(t.id))) {
      fitAll(L);
      return true;
    }
    const laidOpen = p && L.pipelines.get(p.id)?.open;
    if (p && (P.has(p.id) ? p.blocks === null || (p.blocks.length && !laidOpen) : laidOpen)) return false;
    const rootBox = t.how === `fit` && p === wf.root && L.pipelines.get(p.id);
    if (rootBox) {
      void rf.setViewport(firstView(wholeBox(L), rootBox, rf.getViewport(), vw, vh));
      return true;
    }
    const b = boxOf(wf, L, t.id);
    const blk = t.job === undefined ? undefined : wf.blocks.get(t.id);
    const row = blk?.jobs[t.job] && jobRow(blk, t.job);
    if (!b || (blk && (!row || b.h < row.top))) return false;
    const box = row ? { x: b.x, y: b.y + row.top, w: b.w, h: row.h } : b;
    const v = rf.getViewport();
    if (t.how === `open`) void rf.setViewport(nextView(`keep`, box, 1, v, vw, vh, t.at));
    const next = nextView(t.how, box, p ? 1.12 : 1.6, v, vw, vh, t.at);
    const glide = (t.how === `focus` || t.how === `open`) && !window.matchMedia(`(prefers-reduced-motion: reduce)`).matches;
    if (next) void rf.setViewport(next, { duration: glide ? GLIDE_MS : 0, interpolate: `linear` });
    return true;
  };

  const settle = (L: MapLayout) => {
    if (target && go(L, target)) target = null;
  };

  useEffect(() => {
    if (!wf) return;
    let alive = true;
    document.fonts.ready
      .then(() => layoutMap(wf, (p) => P.has(p.id), (b) => blockSize(b, B.has(b.id)), CARD, (p) => detailsBand(p, D)))
      .then((L) => alive && setLayout(L))
      .catch(() => {
        if (alive) layoutError.value = `Couldn't lay out this workflow. Reload the page to try again.`;
      });
    return () => {
      alive = false;
    };
  }, [key]);

  const graph = useMemo(() => (layout && wf ? build(wf, layout) : null), [layout]);

  useEffect(() => {
    if (graph && layout) requestAnimationFrame(() => settle(layout));
  }, [graph, vw, vh]);

  useEffect(() => {
    if (!f || !wf || f.seq === handledSeq.current) return;
    const blockId = f.kind === `job` ? wf.jobs.get(f.id)?.block.id : f.kind === `block` ? f.id : null;
    const p = blockId ? wf.blocks.get(blockId)?.pipeline : wf.pipelineById.get(f.id);
    if (!p) return;
    handledSeq.current = f.seq;
    const job = f.kind === `job` ? wf.jobs.get(f.id).block.jobs.findIndex((j) => j.key === f.id) : undefined;
    aim({ id: blockId ?? p.id, how: `focus`, job });
    if (!P.has(p.id)) toggle(openPipelines, p.id, true);
    if (f.kind === `job` && !B.has(blockId)) toggle(openBlocks, blockId, true);
    if (layout) settle(layout);
  }, [f?.seq, wf]);

  const openMatches = () => {
    aim({ id: ``, how: `all` });
    openPipelines.value = new Set([...P, ...[...h.pipelines].map((p) => p.id)]);
    if (h.ordered.length <= 40) openBlocks.value = new Set([...B, ...[...h.blocks].map((b) => b.id)]);
  };

  if (!graph) return <div className="wf-map-loading">Loading the workflow…</div>;
  const lead = layout.pipelines.get(selected.value);
  return (
    <ReactFlow
      nodes={graph.nodes}
      edges={graph.edges}
      nodeTypes={nodeTypes}
      edgeTypes={edgeTypes}
      minZoom={0.05}
      maxZoom={2}
      panOnScroll
      onlyRenderVisibleElements
      nodesConnectable={false}
      nodesDraggable={false}
      elementsSelectable={false}
      zoomOnDoubleClick={false}
      onMoveStart={() => (popover.value = null)}
    >
      <Background gap={32} size={1.2}/>
      <Controls showInteractive={false} position="bottom-left"/>
      <MiniMap
        pannable
        zoomable
        position="bottom-right"
        style={{ width: 168, height: 110 }}
        maskStrokeColor="#000"
        maskStrokeWidth={3}
        nodeClassName={(n) => {
          const id = (n.data as { id: string, }).id;
          if (n.type === `block`) {
            const b = wf?.blocks.get(id);
            return `wf-map-mm-block ${b ? `wf-map-st-${blockStatus(b)}` : ``}`;
          }
          return `wf-map-mm-${n.type} wf-map-st-${wf?.pipelineById.get(id)?.status ?? `pending`}`;
        }}
      />
      <Panel position="top-right">
        <div className="wf-map-tools">
          <button className="btn btn-secondary btn-small" onClick={() => fitAll(layout)}>
            Fit workflow
          </button>
          <button className="btn btn-secondary btn-small" onClick={() => (aim({ id: ``, how: `all` }), (openPipelines.value = new Set(wf.pipelines.map((p) => p.id))))}>
            Open all pipelines
          </button>
          <button className="btn btn-secondary btn-small" onClick={() => (aim({ id: ``, how: `all` }), (openPipelines.value = new Set()), (openBlocks.value = new Set()))}>
            Close all pipelines
          </button>
          <BlocksToggle pipelines={wf.pipelines.filter((p) => P.has(p.id))} anchor={lead ? { id: selected.value, how: `keep`, at: lead } : null}/>
          <span className="wf-map-zoom">{Math.round(zoom * 100)}%</span>
        </div>
      </Panel>
      <Panel position="bottom-center" className="wf-map-dock">
        <div className="wf-map-dock-bar">
          <Search/>
          <Chips/>
          <Stepper/>
          {h.active && (
            <button className="btn btn-secondary btn-small" onClick={openMatches} disabled={!h.pipelines.size}>
              Open matches
            </button>
          )}
        </div>
      </Panel>
    </ReactFlow>
  );
};

export const MapCanvas = () => (
  <ReactFlowProvider>
    <WorkflowMap/>
  </ReactFlowProvider>
);
