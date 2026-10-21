import { useEffect, useMemo, useRef, useState } from "preact/hooks";
import { signal } from "@preact/signals";
import { BaseEdge, Background, Controls, Edge, EdgeProps, Handle, MiniMap, Node, NodeProps, Panel, Position, ReactFlow, ReactFlowProvider, useReactFlow, useStore } from "@xyflow/react";
import { Workflow, blockStatus, pipelineJobs } from "./model";
import { focus, hits, selected, workflow } from "./store";
import { MapLayout, Point, layoutMap } from "./layout";
import { BlockCard, Counts, Duration, Highlight, PipelineTitle, StatusBar, StatusIcon, jobSummary } from "./ui";

const CARD = { w: 300, h: 72 };
const BLOCK = { w: 230, h: 74 };
const OPEN_BLOCK_W = 260;
const JOB_ROW_H = 23;
const BLOCK_HEAD_H = 40;

const CLICKABLE = { pointerEvents: `all` as const };

export const openPipelines = signal<Set<string>>(new Set());
export const openBlocks = signal<Set<string>>(new Set());

interface Target { id: string, how: `fit` | `center`, job?: number, }
let pending: Target | null = null;

const toggle = (s: typeof openPipelines, id: string, on?: boolean) => {
  const next = new Set(s.value);
  (on ?? !next.has(id)) ? next.add(id) : next.delete(id);
  s.value = next;
};

const edgeKind = (trigger: string) => (trigger === `AUTO_PROMOTION` ? `auto` : trigger === `PIPELINE_PARTIAL_RERUN` ? `rerun` : `manual`);

const CardNode = ({ data }: NodeProps<Node<{ id: string, }>>) => {
  const p = workflow.value?.pipelineById.get(data.id);
  const h = hits.value;
  if (!p) return null;
  const n = h.perPipeline.get(p) ?? 0;
  const jobs = pipelineJobs(p);
  return (
    <button
      className={`wf-map-card ${selected.value === p.id ? `selected` : ``} ${h.active && !n ? `dim` : ``}`}
      onClick={() => {
        selected.value = p.id;
        pending = { id: p.id, how: `fit` };
        toggle(openPipelines, p.id, true);
      }}
    >
      <Handle type="target" id="in" position={Position.Left} isConnectable={false}/>
      <span className="wf-map-card-row">
        <StatusIcon status={p.status} size={18}/>
        <span className="wf-map-card-title">
          <PipelineTitle p={p}/>
        </span>
        <Duration start={p.runningAt} end={p.doneAt} running={p.status === `running`}/>
      </span>
      {p.blocks ? <StatusBar jobs={jobs}/> : <span className="wf-map-bar loading"/>}
      <span className="wf-map-card-row wf-map-card-meta">
        {p.errorDescription ? (
          <span className="wf-map-error">Pipeline failed to start</span>
        ) : p.blocks ? (
          <span>
            {p.blocks.length} blocks · {jobs.length} jobs
          </span>
        ) : (
          <span>Loading blocks…</span>
        )}
        {h.active ? <span className={`wf-map-match ${n ? `` : `zero`}`}>{n} matching</span> : <Counts jobs={jobs}/>}
      </span>
      <Handle type="source" id="out" position={Position.Right} isConnectable={false}/>
    </button>
  );
};

const PipelineNode = ({ data }: NodeProps<Node<{ id: string, }>>) => {
  const p = workflow.value?.pipelineById.get(data.id);
  const h = hits.value;
  if (!p) return null;
  return (
    <div className={`wf-map-pipeline ${selected.value === p.id ? `selected` : ``} ${h.active && !h.pipelines.has(p) ? `dim` : ``}`} onClick={() => (selected.value = p.id)}>
      <Handle type="target" id="in" position={Position.Left} isConnectable={false} style={{ top: 34 }}/>
      <div className="wf-map-pipeline-head">
        <button
          className="wf-map-collapse"
          aria-label={`Collapse ${p.name}`}
          title="Collapse to a card"
          onClick={(e) => {
            e.stopPropagation();
            pending = { id: p.id, how: `center` };
            toggle(openPipelines, p.id, false);
          }}
        >
          ▾
        </button>
        <StatusIcon status={p.status} size={18}/>
        <span className="wf-map-pipeline-title">
          <PipelineTitle p={p}/>
        </span>
        <span className="wf-map-pipeline-meta">{p.yamlFile}</span>
        <Duration start={p.runningAt} end={p.doneAt} running={p.status === `running`}/>
        <Counts jobs={pipelineJobs(p)}/>
      </div>
      <Handle type="source" id="out" position={Position.Right} isConnectable={false} style={{ top: 34 }}/>
    </div>
  );
};

const BlockNode = ({ data }: NodeProps<Node<{ id: string, }>>) => {
  const b = workflow.value?.blocks.get(data.id);
  const h = hits.value;
  const f = focus.value;
  if (!b) return null;
  const st = blockStatus(b);
  const flip = () => {
    pending = { id: b.id, how: `center` };
    toggle(openBlocks, b.id);
  };
  return (
    <div className={`wf-map-node ${h.active && !h.blocks.has(b) ? `dim` : ``}`}>
      <Handle type="target" position={Position.Left} isConnectable={false}/>
      {openBlocks.value.has(b.id) ? (
        <BlockCard block={b} onHeaderClick={flip}/>
      ) : (
        <button className={`wf-map-summary ${f && (f.id === b.id || f.id.startsWith(`${b.id}#`)) ? `focused` : ``}`} onClick={flip}>
          <span className="wf-map-summary-name">
            <StatusIcon status={st}/>
            <span>
              <Highlight text={b.name}/>
            </span>
          </span>
          <StatusBar jobs={b.jobs}/>
          <span className="wf-map-summary-meta">{jobSummary(b.jobs)}</span>
        </button>
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

const RouteEdge = ({ id, data }: EdgeProps<Edge<{ points: Point[], }>>) => <BaseEdge id={id} path={rounded(data.points)}/>;

const nodeTypes = { card: CardNode, pipeline: PipelineNode, block: BlockNode };
const edgeTypes = { route: RouteEdge };

function build(wf: Workflow, L: MapLayout) {
  const nodes: Node[] = [];
  const edges: Edge[] = [];
  for (const p of wf.pipelines) {
    const box = L.pipelines.get(p.id);
    if (!box) continue;
    nodes.push({ id: p.id, type: box.open ? `pipeline` : `card`, position: { x: box.x, y: box.y }, width: box.w, height: box.h, style: CLICKABLE, data: { id: p.id }, draggable: false, selectable: false });
    if (box.open) {
      for (const b of p.blocks ?? []) {
        const bb = L.blocks.get(b.id);
        if (!bb) continue;
        nodes.push({ id: b.id, type: `block`, parentId: p.id, position: { x: bb.x, y: bb.y }, width: bb.w, height: bb.h, style: CLICKABLE, data: { id: b.id }, draggable: false, selectable: false });
        for (const d of b.deps) {
          const id = `${d.id}->${b.id}`;
          edges.push({ id, type: `route`, source: d.id, target: b.id, className: `dep`, focusable: false, data: { points: L.routes.get(id) ?? [] } });
        }
      }
    }
    if (p.parent && L.pipelines.has(p.parent.id)) {
      const id = `${p.parent.id}=>${p.id}`;
      edges.push({ id, type: `route`, source: p.parent.id, sourceHandle: `out`, target: p.id, targetHandle: `in`, className: `promo ${edgeKind(p.trigger)}`, focusable: false, data: { points: L.routes.get(id) ?? [] } });
    }
  }
  return { nodes, edges };
}

function structureKey(wf: Workflow, open: Set<string>, openB: Set<string>) {
  return wf.pipelines
    .map((p) => {
      const blocks = open.has(p.id) && p.blocks ? p.blocks.map((b) => `${b.name}:${b.deps.length}:${openB.has(b.id) ? b.jobs.length : `-`}`).join(`,`) : `closed`;
      return `${p.id}<${p.parent?.id ?? ``}>${blocks}`;
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
  const f = focus.value;
  const h = hits.value;
  const zoom = useStore((s) => s.transform[2]);
  const vw = useStore((s) => s.width);
  const vh = useStore((s) => s.height);
  const [layout, setLayout] = useState<MapLayout | null>(null);
  const initialFit = useRef(false);
  const key = wf ? structureKey(wf, P, B) : ``;

  const go = (L: MapLayout, t: Target) => {
    const b = boxOf(wf, L, t.id);
    if (!b || (t.job !== undefined && b.h < BLOCK_HEAD_H + t.job * JOB_ROW_H)) return false;
    const cx = b.x + b.w / 2;
    if (t.how === `center`) {
      void rf.setCenter(cx, b.y + b.h / 2, { zoom: rf.getZoom(), duration: 350 });
    } else if (t.job !== undefined) {
      void rf.setCenter(cx, b.y + BLOCK_HEAD_H + t.job * JOB_ROW_H + 11, { zoom: Math.max(rf.getZoom(), 1), duration: 450 });
    } else {
      const pad = L.pipelines.has(t.id) ? 1.12 : 1.6;
      const z = Math.max(0.1, Math.min(1, vw / (b.w * pad), vh / (b.h * pad)));
      void rf.setViewport({ x: vw / 2 - cx * z, y: vh / 2 - (b.y + b.h / 2) * z, zoom: z }, { duration: 450 });
    }
    return true;
  };

  useEffect(() => {
    if (!wf) return;
    let alive = true;
    void layoutMap(
      wf,
      (p) => P.has(p.id),
      (b) => (B.has(b.id) ? { w: OPEN_BLOCK_W, h: BLOCK_HEAD_H + b.jobs.length * JOB_ROW_H + 8 } : BLOCK),
      CARD
    ).then((L) => alive && setLayout(L));
    return () => {
      alive = false;
    };
  }, [key]);

  const graph = useMemo(() => (layout && wf ? build(wf, layout) : null), [layout]);

  useEffect(() => {
    if (!graph || !layout) return;
    const t = pending;
    pending = null;
    requestAnimationFrame(() => {
      if (t) {
        go(layout, t);
      } else if (!initialFit.current) {
        const sel = wf.pipelineById.get(selected.value);
        if (!sel || sel.blocks !== null) {
          initialFit.current = true;
          if (!go(layout, { id: selected.value, how: `fit` })) void rf.fitView({ padding: 0.06, maxZoom: 1 });
        }
      }
    });
  }, [graph]);

  useEffect(() => {
    if (!f || !wf) return;
    const blockId = f.kind === `job` ? wf.jobs.get(f.id)?.block.id : f.kind === `block` ? f.id : null;
    const p = blockId ? wf.blocks.get(blockId)?.pipeline : wf.pipelineById.get(f.id);
    if (!p) return;
    const needP = !P.has(p.id);
    const needB = f.kind === `job` && !B.has(blockId);
    const job = f.kind === `job` ? wf.jobs.get(f.id).block.jobs.findIndex((j) => j.key === f.id) : undefined;
    pending = { id: blockId ?? p.id, how: `fit`, job };
    if (needP) toggle(openPipelines, p.id, true);
    if (needB) toggle(openBlocks, blockId, true);
    if (!needP && !needB && layout && go(layout, pending)) pending = null;
  }, [f?.seq]);

  const openMatches = () => {
    pending = null;
    initialFit.current = false;
    openPipelines.value = new Set([...P, ...[...h.pipelines].map((p) => p.id)]);
    if (h.ordered.length <= 40) openBlocks.value = new Set([...B, ...[...h.blocks].map((b) => b.id)]);
  };

  if (!graph) return <div className="wf-map-loading">Loading the workflow…</div>;
  return (
    <ReactFlow
      nodes={graph.nodes}
      edges={graph.edges}
      nodeTypes={nodeTypes}
      edgeTypes={edgeTypes}
      minZoom={0.05}
      maxZoom={2}
      onlyRenderVisibleElements
      nodesConnectable={false}
      nodesDraggable={false}
      elementsSelectable={false}
      zoomOnDoubleClick={false}
    >
      <Background gap={32} size={1.2}/>
      <Controls showInteractive={false} position="bottom-left"/>
      <MiniMap
        pannable
        zoomable
        position="bottom-right"
        style={{ width: 168, height: 110 }}
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
          <button className="btn btn-secondary btn-small" onClick={() => void rf.fitView({ duration: 400, padding: 0.06 })}>
            Fit workflow
          </button>
          <button className="btn btn-secondary btn-small" onClick={() => ((pending = null), (openPipelines.value = new Set(wf.pipelines.map((p) => p.id))))}>
            Open all
          </button>
          <button className="btn btn-secondary btn-small" onClick={() => ((pending = null), (openPipelines.value = new Set()), (openBlocks.value = new Set()))}>
            Close all
          </button>
          {h.active && (
            <button className="btn btn-secondary btn-small" onClick={openMatches} disabled={!h.pipelines.size}>
              Open matches
            </button>
          )}
          <span className="wf-map-zoom">{Math.round(zoom * 100)}%</span>
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
