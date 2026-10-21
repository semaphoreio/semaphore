import { computed, signal } from "@preact/signals";
import * as APIRequest from "js/toolbox/api_request";
import { ApiPipelineDetail, ApiWorkflow, Block, Job, Pipeline, Status, blockStatus, buildWorkflow } from "./model";

export interface Config {
  workflowUrl: string;
  pipelineUrl: string;
  switchUrl: string;
  elkWorkerUrl: string;
  selectedPipelineId: string;
  pollInterval: number;
  nonce: string;
}

export const tree = signal<ApiWorkflow | null>(null);
export const details = signal<Record<string, ApiPipelineDetail>>({});
export const loadError = signal<string | null>(null);
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

export const hits = computed<Hits>(() => {
  const wf = workflow.value;
  const q = query.value.trim().toLowerCase();
  const st = statuses.value;
  const out: Hits = { active: q.length > 0 || st.size > 0, jobs: new Set(), blocks: new Set(), pipelines: new Set(), perPipeline: new Map(), ordered: [] };
  if (!out.active || !wf) return out;
  for (const p of wf.pipelines) {
    const pName = includes(p.name, q);
    for (const b of p.blocks ?? []) {
      const bName = includes(b.name, q);
      for (const j of b.jobs) {
        if (st.size && !st.has(j.status)) continue;
        if (q && !pName && !bName && !includes(j.name, q)) continue;
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
  tree.value = null;
  details.value = {};
  loadError.value = null;
  query.value = ``;
  statuses.value = new Set();
  scope.value = `all`;
  cursor.value = -1;
  focus.value = null;
  selected.value = selectedPipelineId;
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

const DETAIL_CONCURRENCY = 4;

async function fetchJson<T>(url: string): Promise<T | null> {
  const response = await APIRequest.get<T>(url);
  return response.error ? null : response.data;
}

export async function refresh(config: Config) {
  const started = generation;
  const nextTree = await fetchJson<ApiWorkflow>(config.workflowUrl);
  if (started !== generation) return;
  if (!nextTree) {
    loadError.value = `Couldn't load this workflow's pipelines. Retrying.`;
    return;
  }
  loadError.value = null;
  tree.value = nextTree;

  const known = details.value;
  const due = nextTree.pipelines.filter((p) => !known[p.id]?.done || p.state !== `DONE`);
  const fetched: Record<string, ApiPipelineDetail> = {};
  const queue = [...due];
  const worker = async () => {
    for (let p = queue.shift(); p; p = queue.shift()) {
      const detail = await fetchJson<ApiPipelineDetail>(config.pipelineUrl.replace(`__PIPELINE_ID__`, p.id));
      if (detail) fetched[p.id] = detail;
    }
  };
  await Promise.all(Array.from({ length: Math.min(DETAIL_CONCURRENCY, queue.length) }, worker));
  if (started === generation && Object.keys(fetched).length) details.value = { ...details.value, ...fetched };
}
