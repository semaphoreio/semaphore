import ElkConstructor, { ELK, ElkExtendedEdge, ElkNode } from "elkjs/lib/elk-api";
import { Block, Pipeline, Workflow } from "./model";

export interface Box {
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface Point {
  x: number;
  y: number;
}

export interface MapLayout {
  pipelines: Map<string, Box & { open: boolean, }>;
  blocks: Map<string, Box>;
  routes: Map<string, Point[]>;
  labels: Map<string, Point>;
}

export function promotionLabel(p: Pipeline) {
  const promotion = p.trigger === `PIPELINE_PARTIAL_RERUN` ? null : p.parent?.promotions?.find((x) => x.pipelines.includes(p));
  if (!promotion) return null;
  const event = promotion.events.find((e) => e.pipeline_id === p.id);
  const name = promotion.name.toLowerCase() === p.name.toLowerCase() ? null : promotion.name;
  const by = event && !event.auto && event.author ? `by ${event.author}` : null;
  return [name, by].filter(Boolean).join(` · `) || null;
}

const PIPE_PAD = { top: 72, side: 28, bottom: 28 };
const MIN_OPEN_W = 460;

let elk: ELK | null = null;
const innerCache = new Map<string, Promise<ElkNode>>();

export function initLayout(workerUrl: string, onWorkerError: () => void) {
  elk?.terminateWorker();
  elk = new ElkConstructor({
    workerUrl,
    workerFactory: (url) => {
      const worker = new Worker(url);
      worker.addEventListener(`error`, onWorkerError);
      return worker;
    },
  });
  innerCache.clear();
}

function inner(p: Pipeline, size: (b: Block) => { w: number, h: number, }) {
  const blocks = p.blocks ?? [];
  const sizes = blocks.map(size);
  const key = `${p.id}|${blocks.map((b, i) => `${b.name}:${b.deps.map((d) => d.name).join(`+`)}:${sizes[i].w}x${sizes[i].h}`).join(`,`)}`;
  if (!innerCache.has(key)) {
    const layout = elk.layout({
      id: p.id,
      layoutOptions: {
        "elk.algorithm": `layered`,
        "elk.direction": `RIGHT`,
        "elk.edgeRouting": `ORTHOGONAL`,
        "elk.spacing.nodeNode": `24`,
        "elk.spacing.edgeNode": `14`,
        "elk.layered.spacing.nodeNodeBetweenLayers": `64`,
        "elk.layered.nodePlacement.bk.fixedAlignment": `BALANCED`,
        "elk.padding": `[top=${PIPE_PAD.top},left=${PIPE_PAD.side},bottom=${PIPE_PAD.bottom},right=${PIPE_PAD.side}]`,
      },
      children: blocks.map((b, i) => ({ id: b.id, width: sizes[i].w, height: sizes[i].h })),
      edges: blocks.flatMap((b) => b.deps.map((d) => ({ id: `${d.id}->${b.id}`, sources: [d.id], targets: [b.id] }))),
    });
    layout.catch(() => innerCache.delete(key));
    innerCache.set(key, layout);
  }
  return innerCache.get(key);
}

const sectionPoints = (e: ElkExtendedEdge, dx: number, dy: number): Point[] =>
  (e.sections ?? []).flatMap((s) => [s.startPoint, ...(s.bendPoints ?? []), s.endPoint]).map((pt) => ({ x: pt.x + dx, y: pt.y + dy }));

export async function layoutMap(
  wf: Workflow,
  isOpen: (p: Pipeline) => boolean,
  blockSize: (b: Block) => { w: number, h: number, },
  closed: { w: number, h: number, }
): Promise<MapLayout> {
  const inners = await Promise.all(wf.pipelines.map((p) => (isOpen(p) && p.blocks?.length ? inner(p, blockSize) : null)));
  const outer = await elk.layout({
    id: `workflow`,
    layoutOptions: {
      "elk.algorithm": `layered`,
      "elk.direction": `RIGHT`,
      "elk.edgeRouting": `ORTHOGONAL`,
      "elk.spacing.nodeNode": `16`,
      "elk.layered.spacing.nodeNodeBetweenLayers": `80`,
      "elk.layered.considerModelOrder.strategy": `NODES_AND_EDGES`,
      "elk.layered.nodePlacement.strategy": `BRANDES_KOEPF`,
    },
    children: wf.pipelines.map((p, i) => {
      const g = inners[i];
      return { id: p.id, width: g ? Math.max(MIN_OPEN_W, g.width) : closed.w, height: g ? g.height : closed.h };
    }),
    edges: wf.pipelines
      .filter((p) => p.parent)
      .map((p): ElkExtendedEdge => {
        const label = promotionLabel(p);
        return {
          id: `${p.parent.id}=>${p.id}`,
          sources: [p.parent.id],
          targets: [p.id],
          labels: label ? [{ text: label, width: label.length * 6.5 + 18, height: 20 }] : [],
        };
      }),
  });

  const layout: MapLayout = { pipelines: new Map(), blocks: new Map(), routes: new Map(), labels: new Map() };
  for (const c of outer.children ?? []) layout.pipelines.set(c.id, { x: c.x, y: c.y, w: c.width, h: c.height, open: false });
  for (const e of outer.edges ?? []) {
    layout.routes.set(e.id, sectionPoints(e, 0, 0));
    const l = e.labels?.[0];
    if (l) layout.labels.set(e.id, { x: l.x + l.width / 2, y: l.y + l.height / 2 });
  }
  inners.forEach((g, i) => {
    if (!g) return;
    const box = layout.pipelines.get(wf.pipelines[i].id);
    box.open = true;
    for (const c of g.children ?? []) layout.blocks.set(c.id, { x: c.x, y: c.y, w: c.width, h: c.height });
    for (const e of g.edges ?? []) layout.routes.set(e.id, sectionPoints(e, box.x, box.y));
  });
  return layout;
}
