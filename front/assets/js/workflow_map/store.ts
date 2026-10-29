import { computed, signal } from "@preact/signals";
import * as APIRequest from "js/toolbox/api_request";
import { ApiPipelineDetail, ApiWorkflow, Block, Job, Pipeline, Promotion, Status, blockStatus, buildWorkflow } from "./model";

export interface Config {
  workflowUrl: string;
  pipelinesUrl: string;
  elkWorkerUrl: string;
  selectedPipelineId: string;
  pollInterval: number;
}

export const tree = signal<ApiWorkflow | null>(null);
export const details = signal<Record<string, ApiPipelineDetail>>({});
export const loadError = signal<string | null>(null);
export const layoutError = signal<string | null>(null);
export const popover = signal<{ kind: `promote` | `error`, id: string, x: number, y: number, } | null>(null);
export const workflow = computed(() => (tree.value ? buildWorkflow(tree.value, details.value) : null));
export const now = signal(Math.floor(Date.now() / 1000));

export const query = signal(``);
export const statuses = signal<Set<Status>>(new Set());
export const scope = signal<`all` | `pipeline`>(`all`);
export const selected = signal<string>(``);
export const cursor = signal(-1);

export interface FocusTarget { kind: `pipeline` | `block` | `job`, id: string, seq: number, }
export const focus = signal<FocusTarget | null>(null);

let seq = 0;
let generation = 0;
const stale = new Set<string>();
let nudge = () => undefined;

export const onNudge = (fn: () => void) => {
  nudge = fn;
};

export function focusOn(kind: FocusTarget[`kind`], id: string) {
  const wf = workflow.value;
  const pipelineId = kind === `pipeline` ? id : kind === `block` ? wf?.blocks.get(id)?.pipeline.id : wf?.jobs.get(id)?.block.pipeline.id;
  if (!pipelineId) return;
  selected.value = pipelineId;
  focus.value = { kind, id, seq: ++seq };
}

export interface Hits {
  active: boolean;
  jobs: Set<Job>;
  blocks: Set<Block>;
  pipelines: Set<Pipeline>;
  perPipeline: Map<Pipeline, number>;
  ordered: Job[];
}

const includes = (name: string, q: string) => name.toLowerCase().includes(q);

const named = (p: Pipeline, b: Block, j: Job, q: string) => !q || includes(p.name, q) || includes(b.name, q) || includes(j.name, q);

export const queryJobs = computed<Job[]>(() => {
  const q = query.value.trim().toLowerCase();
  return (workflow.value?.pipelines ?? []).flatMap((p) => (p.blocks ?? []).flatMap((b) => b.jobs.filter((j) => named(p, b, j, q))));
});

export const hits = computed<Hits>(() => {
  const wf = workflow.value;
  const q = query.value.trim().toLowerCase();
  const st = statuses.value;
  const out: Hits = { active: q.length > 0 || st.size > 0, jobs: new Set(), blocks: new Set(), pipelines: new Set(), perPipeline: new Map(), ordered: [] };
  if (!out.active || !wf) return out;
  for (const p of wf.pipelines) {
    for (const b of p.blocks ?? []) {
      for (const j of b.jobs) {
        if (st.size && !st.has(j.status)) continue;
        if (!named(p, b, j, q)) continue;
        out.jobs.add(j);
        out.blocks.add(b);
        out.pipelines.add(p);
        out.ordered.push(j);
        out.perPipeline.set(p, (out.perPipeline.get(p) ?? 0) + 1);
      }
    }
  }
  return out;
});

export interface SearchResult {
  kind: FocusTarget[`kind`];
  id: string;
  label: string;
  pipeline: Pipeline;
  status: Status;
  context: string;
}

export const results = computed<SearchResult[]>(() => {
  const wf = workflow.value;
  const q = query.value.trim().toLowerCase();
  if (!q || !wf) return [];
  const st = statuses.value;
  const out: SearchResult[] = [];
  const pipelines = scope.value === `pipeline` ? [wf.pipelineById.get(selected.value)].filter(Boolean) : wf.pipelines;
  for (const p of pipelines) {
    if (includes(p.name, q) && (!st.size || st.has(p.status))) {
      out.push({ kind: `pipeline`, id: p.id, label: p.name, pipeline: p, status: p.status, context: p.yamlFile });
    }
    for (const b of p.blocks ?? []) {
      if (includes(b.name, q) && (!st.size || b.jobs.some((j) => st.has(j.status)))) {
        out.push({ kind: `block`, id: b.id, label: b.name, pipeline: p, status: blockStatus(b), context: `${b.jobs.length} jobs` });
      }
      for (const j of b.jobs) {
        if (includes(j.name, q) && (!st.size || st.has(j.status))) {
          out.push({ kind: `job`, id: j.key, label: j.name, pipeline: p, status: j.status, context: b.name });
        }
      }
    }
  }
  return out;
});

export function resetState(selectedPipelineId: string) {
  generation++;
  stale.clear();
  tree.value = null;
  details.value = {};
  loadError.value = null;
  layoutError.value = null;
  popover.value = null;
  query.value = ``;
  statuses.value = new Set();
  scope.value = `all`;
  cursor.value = -1;
  focus.value = null;
  selected.value = selectedPipelineId;
}

export function togglePopover(kind: `promote` | `error`, id: string, anchor: Element) {
  const open = popover.value;
  const r = anchor.getBoundingClientRect();
  popover.value = open?.kind === kind && open.id === id ? null : { kind, id, x: r.left, y: r.bottom + 4 };
}

export function toggleStatus(s: Status) {
  const next = new Set(statuses.value);
  next.has(s) ? next.delete(s) : next.add(s);
  statuses.value = next;
  cursor.value = -1;
}

export function clearFilters() {
  statuses.value = new Set();
  query.value = ``;
  cursor.value = -1;
}

export function step(dir: 1 | -1) {
  const list = hits.value.ordered;
  if (!list.length) return;
  const next = cursor.value < 0 ? (dir === 1 ? 0 : list.length - 1) : (cursor.value + dir + list.length) % list.length;
  cursor.value = next;
  focusOn(`job`, list[next].key);
}

async function fetchJson<T>(url: string): Promise<T | null> {
  const response = await APIRequest.get<T>(url);
  return response.error ? null : response.data;
}

type FetchedDetail = Omit<ApiPipelineDetail, `promotions`> & { promotions: ApiPipelineDetail[`promotions`] | null, };

export async function refresh(config: Config): Promise<boolean> {
  const started = generation;
  const nextTree = await fetchJson<ApiWorkflow>(config.workflowUrl);
  if (started !== generation) return false;
  if (!nextTree) {
    loadError.value = `Couldn't load this workflow's pipelines. Retrying.`;
    return false;
  }
  const children = (t: ApiWorkflow | null, id: string) => t?.pipelines.filter((p) => p.parent_id === id).length ?? 0;
  const previous = tree.value;
  const treeChanged = JSON.stringify(nextTree) !== JSON.stringify(previous);
  loadError.value = null;
  if (treeChanged) tree.value = nextTree;

  const known = details.value;
  const fresh = (id: string) =>
    !known[id] ||
    stale.has(id) ||
    known[id].promotions.some((promotion) => promotion.events.some((e) => !e.processed)) ||
    children(nextTree, id) > children(previous, id);
  const due = nextTree.pipelines.filter((p) => fresh(p.id) || p.state !== `DONE` || !known[p.id].done);
  if (!due.length) return treeChanged;
  const withPromotions = due.filter((p) => fresh(p.id) || p.state === `DONE`).map((p) => p.id);
  const params = new URLSearchParams({ ids: due.map((p) => p.id).join(`,`), promotions: withPromotions.join(`,`) });
  due.forEach((p) => stale.delete(p.id));

  const response = await fetchJson<{ pipelines: FetchedDetail[], }>(`${config.pipelinesUrl}?${params.toString()}`);
  if (started !== generation) return treeChanged;
  const returned = new Map(response?.pipelines.map((d) => [d.id, d]));
  withPromotions.filter((id) => !returned.get(id)?.promotions).forEach((id) => stale.add(id));
  if (!response) return treeChanged;
  const fetched: Record<string, ApiPipelineDetail> = {};
  for (const d of response.pipelines) fetched[d.id] = { ...d, promotions: d.promotions ?? known[d.id]?.promotions ?? [] };
  const detailsChanged = Object.values(fetched).some((d) => JSON.stringify(d) !== JSON.stringify(known[d.id]));
  if (detailsChanged) details.value = { ...details.value, ...fetched };
  return treeChanged || detailsChanged;
}

interface ActionResult {
  message?: string;
  error?: string;
  pipeline_id?: string;
}

export async function promote(pipeline: Pipeline, promotion: Promotion, values: Record<string, string>): Promise<string | null> {
  const response = await APIRequest.post(promotion.trigger_url, { parameters: values });
  if (response.error) return response.error;
  stale.add(pipeline.id);
  nudge();
  return null;
}

export async function stopPipeline(pipeline: Pipeline): Promise<string | null> {
  const response = await APIRequest.post<ActionResult>(pipeline.stopUrl);
  const error = response.error ?? response.data?.error;
  if (error) return error;
  stale.add(pipeline.id);
  nudge();
  return null;
}

export async function rerunPipeline(pipeline: Pipeline): Promise<string | null> {
  const response = await APIRequest.post<ActionResult>(pipeline.rebuildUrl);
  const error = response.error ?? response.data?.error;
  if (error) return error;
  if (response.data?.pipeline_id) focusOn(`pipeline`, response.data.pipeline_id);
  nudge();
  return null;
}
