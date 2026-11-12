import ElkConstructor, { ELK, ElkExtendedEdge, ElkNode } from "elkjs/lib/elk-api";
import { Block, Pipeline, Workflow } from "./model";
import { BLOCK, BLOCK_GAP } from "./lines";

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

const PIPE_PAD = { top: 88, side: 28, bottom: 28 };
export const MIN_OPEN_W = 460;
const LABEL = { width: 160, height: 20 };
const LAYER_GAP = 64;
const ASPECT = 2.4;

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

function component(p: Pipeline, blocks: Block[], size: (b: Block) => { w: number, h: number, }) {
  const sizes = blocks.map(size);
  const key = `${p.id}|${blocks.map((b, i) => `${b.name}:${b.deps.map((d) => d.name).join(`+`)}:${sizes[i].w}x${sizes[i].h}`).join(`,`)}`;
  if (!innerCache.has(key)) {
    const layout = elk.layout({
      id: p.id,
      layoutOptions: {
        "elk.algorithm": `layered`,
        "elk.direction": `RIGHT`,
        "elk.edgeRouting": `ORTHOGONAL`,
        "elk.spacing.nodeNode": `${BLOCK_GAP}`,
        "elk.spacing.edgeNode": `14`,
        "elk.layered.spacing.nodeNodeBetweenLayers": `${LAYER_GAP}`,
        "elk.layered.nodePlacement.bk.fixedAlignment": `BALANCED`,
        "elk.padding": `[top=0,left=0,bottom=0,right=0]`,
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

async function inner(p: Pipeline, size: (b: Block) => { w: number, h: number, }, top: number) {
  const blocks = (p.blocks ?? []).filter((b) => !b.after);
  const group = new Map(blocks.map((b) => [b, b]));
  const find = (b: Block): Block => (group.get(b) === b ? b : find(group.get(b)));
  blocks.forEach((b) => b.deps.forEach((d) => group.has(d) && group.set(find(b), find(d))));
  const parts = new Map<Block, Block[]>();
  blocks.forEach((b) => parts.set(find(b), [...(parts.get(find(b)) ?? []), b]));
  const groups = [...parts.values()];
  const now = await Promise.all(groups.map((c) => component(p, c, size)));
  const closed = await Promise.all(groups.map((c) => component(p, c, () => BLOCK)));
  const area = closed.reduce((sum, g) => sum + (g.width + LAYER_GAP) * (g.height + BLOCK_GAP), 0);
  const rowWidth = Math.max(...closed.map((g) => g.width), Math.sqrt(area * ASPECT));
  const out = { width: 0, height: 0, blocks: new Map<string, Box>(), routes: new Map<string, Point[]>() };
  let x = 0;
  let y = top;
  let slot = 0;
  let rowH = 0;
  now.forEach((g, i) => {
    if (slot && slot + closed[i].width > rowWidth) {
      x = 0;
      y += rowH + BLOCK_GAP;
      slot = 0;
      rowH = 0;
    }
    const dx = PIPE_PAD.side + x;
    for (const c of g.children) out.blocks.set(c.id, { x: c.x + dx, y: c.y + y, w: c.width, h: c.height });
    for (const e of g.edges) out.routes.set(e.id, sectionPoints(e, dx, y));
    out.width = Math.max(out.width, dx + g.width + PIPE_PAD.side);
    x += g.width + LAYER_GAP;
    slot += closed[i].width + LAYER_GAP;
    rowH = Math.max(rowH, g.height);
  });
  out.height = y + rowH + PIPE_PAD.bottom;
  return out;
}

export async function layoutMap(
  wf: Workflow,
  isOpen: (p: Pipeline) => boolean,
  blockSize: (b: Block) => { w: number, h: number, },
  closed: { w: number, h: number, },
  band: (p: Pipeline) => number
): Promise<MapLayout> {
  const inners = await Promise.all(wf.pipelines.map((p) => (isOpen(p) && p.blocks?.some((b) => !b.after) ? inner(p, blockSize, PIPE_PAD.top + band(p)) : null)));
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
    edges: [
      ...wf.pipelines
        .filter((p) => p.parent)
        .map((p): ElkExtendedEdge => {
          const label = promotionLabel(p);
          return {
            id: `${p.parent.id}=>${p.id}`,
            sources: [p.parent.id],
            targets: [p.id],
            labels: label ? [{ text: label, ...LABEL }] : [],
          };
        }),
    ],
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
    const p = wf.pipelines[i];
    const box = layout.pipelines.get(p.id);
    box.open = true;
    const after = p.blocks.find((b) => b.after);
    if (after) layout.blocks.set(after.id, { x: PIPE_PAD.side, y: PIPE_PAD.top, ...blockSize(after) });
    g.blocks.forEach((b, id) => layout.blocks.set(id, b));
    g.routes.forEach((pts, id) => layout.routes.set(id, pts.map((pt) => ({ x: pt.x + box.x, y: pt.y + box.y }))));
  });
  return layout;
}
