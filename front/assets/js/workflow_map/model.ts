export type Status = `failed` | `running` | `queued` | `stopped` | `pending` | `skipped` | `passed`;

export const STATUSES: Status[] = [`failed`, `running`, `queued`, `stopped`, `pending`, `skipped`, `passed`];

export const STATUS_LABEL: Record<Status, string> = {
  failed: `Failed`,
  running: `Running`,
  queued: `Queued`,
  stopped: `Stopped`,
  pending: `Not started`,
  skipped: `Skipped`,
  passed: `Passed`,
};

export interface ApiPipeline {
  id: string;
  name: string;
  yaml_file: string;
  state: string;
  result: string;
  parent_id: string | null;
  trigger: string;
  switch_id: string | null;
  created_at: number | null;
  running_at: number | null;
  done_at: number | null;
}

export interface ApiWorkflow {
  root_pipeline_id: string;
  pipelines: ApiPipeline[];
}

export interface ApiJob {
  id: string | null;
  name: string;
  status: Status;
  started_at: number | null;
  finished_at: number | null;
  reused: boolean;
}

export interface ApiBlock {
  name: string;
  dependencies: string[];
  jobs: ApiJob[];
}

export interface ApiPipelineDetail {
  id: string;
  state: string;
  result: string;
  error_description: string;
  blocks: ApiBlock[];
  after_jobs: ApiJob[];
}

export interface Job {
  key: string;
  id: string | null;
  name: string;
  status: Status;
  startedAt: number | null;
  finishedAt: number | null;
  reused: boolean;
  block: Block;
}

export interface Block {
  id: string;
  name: string;
  deps: Block[];
  jobs: Job[];
  pipeline: Pipeline;
}

export interface Pipeline {
  id: string;
  name: string;
  yamlFile: string;
  status: Status;
  done: boolean;
  trigger: string;
  switchId: string | null;
  createdAt: number | null;
  runningAt: number | null;
  doneAt: number | null;
  parent: Pipeline | null;
  children: Pipeline[];
  depth: number;
  attempt: number;
  blocks: Block[] | null;
  errorDescription: string;
}

export interface Workflow {
  root: Pipeline;
  pipelines: Pipeline[];
  pipelineById: Map<string, Pipeline>;
  blocks: Map<string, Block>;
  jobs: Map<string, Job>;
}

export const AFTER_PIPELINE = `After pipeline`;

const pipelineStatus = (state: string, result: string): Status => {
  if (state === `DONE`) {
    return result === `PASSED` ? `passed` : result === `FAILED` ? `failed` : `stopped`;
  }
  return state === `RUNNING` || state === `STOPPING` ? `running` : `queued`;
};

function buildBlocks(p: Pipeline, detail: ApiPipelineDetail, wf: Workflow): Block[] {
  const byName = new Map<string, Block>();
  const blocks = detail.blocks.map((b) => {
    const block: Block = { id: `${p.id}/${b.name}`, name: b.name, deps: [], jobs: [], pipeline: p };
    byName.set(b.name, block);
    return block;
  });
  detail.blocks.forEach((b, i) => {
    blocks[i].deps = b.dependencies.map((d) => byName.get(d)).filter(Boolean);
    blocks[i].jobs = b.jobs.map((j, n) => ({
      key: `${blocks[i].id}#${n}`,
      id: j.id,
      name: j.name,
      status: j.status,
      startedAt: j.started_at,
      finishedAt: j.finished_at,
      reused: j.reused,
      block: blocks[i],
    }));
  });
  if (detail.after_jobs.length) {
    const sinks = blocks.filter((b) => !blocks.some((other) => other.deps.includes(b)));
    const after: Block = { id: `${p.id}/${AFTER_PIPELINE}`, name: AFTER_PIPELINE, deps: sinks, jobs: [], pipeline: p };
    after.jobs = detail.after_jobs.map((j, n) => ({
      key: `${after.id}#${n}`,
      id: j.id,
      name: j.name,
      status: j.status,
      startedAt: j.started_at,
      finishedAt: j.finished_at,
      reused: false,
      block: after,
    }));
    blocks.push(after);
  }
  for (const b of blocks) {
    wf.blocks.set(b.id, b);
    for (const j of b.jobs) wf.jobs.set(j.key, j);
  }
  return blocks;
}

export function buildWorkflow(tree: ApiWorkflow, details: Record<string, ApiPipelineDetail>): Workflow | null {
  const pipelineById = new Map<string, Pipeline>();
  for (const a of tree.pipelines) {
    pipelineById.set(a.id, {
      id: a.id,
      name: a.name,
      yamlFile: a.yaml_file,
      status: pipelineStatus(a.state, a.result),
      done: a.state === `DONE`,
      trigger: a.trigger,
      switchId: a.switch_id,
      createdAt: a.created_at,
      runningAt: a.running_at,
      doneAt: a.done_at,
      parent: null,
      children: [],
      depth: 0,
      attempt: 1,
      blocks: null,
      errorDescription: ``,
    });
  }
  const root = pipelineById.get(tree.root_pipeline_id) ?? [...pipelineById.values()][0];
  if (!root) return null;

  for (const a of tree.pipelines) {
    const p = pipelineById.get(a.id);
    const parent = a.parent_id ? pipelineById.get(a.parent_id) : null;
    if (parent && p !== root) {
      p.parent = parent;
      parent.children.push(p);
    }
  }

  const wf: Workflow = { root, pipelines: [], pipelineById, blocks: new Map(), jobs: new Map() };
  const walk = (p: Pipeline, depth: number) => {
    p.depth = depth;
    wf.pipelines.push(p);
    p.children.sort((a, b) => (a.createdAt ?? 0) - (b.createdAt ?? 0));
    const seen = new Map<string, number>();
    for (const c of p.children) {
      seen.set(c.name, (seen.get(c.name) ?? 0) + 1);
      c.attempt = seen.get(c.name);
      walk(c, depth + 1);
    }
  };
  walk(root, 0);
  for (const p of pipelineById.values()) if (!wf.pipelines.includes(p)) walk(p, 0);

  for (const p of wf.pipelines) {
    const detail = details[p.id];
    if (detail) {
      p.blocks = buildBlocks(p, detail, wf);
      p.errorDescription = detail.error_description;
    }
  }
  return wf;
}

const PRECEDENCE: Status[] = [`running`, `queued`, `failed`, `stopped`, `pending`, `passed`, `skipped`];

export function rollup(statuses: Status[]): Status {
  if (statuses.length === 0) return `pending`;
  const set = new Set(statuses);
  if (set.size === 1) return statuses[0];
  if (set.has(`pending`) && set.has(`passed`) && !set.has(`failed`) && !set.has(`stopped`) && !set.has(`running`) && !set.has(`queued`)) {
    return `running`;
  }
  return PRECEDENCE.find((s) => set.has(s));
}

export const blockStatus = (b: Block) => rollup(b.jobs.map((j) => j.status));

export const pipelineJobs = (p: Pipeline): Job[] => (p.blocks ?? []).flatMap((b) => b.jobs);

export function countJobs(jobs: Job[]): Record<Status, number> {
  const c = Object.fromEntries(STATUSES.map((s) => [s, 0])) as Record<Status, number>;
  for (const j of jobs) c[j.status]++;
  return c;
}

export function formatDuration(total: number): string {
  const seconds = Math.max(0, Math.floor(total));
  const two = (n: number) => String(n).padStart(2, `0`);
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const rest = seconds % 60;
  if (days) return `${days}d ${two(hours)}:${two(minutes)}:${two(rest)}`;
  if (hours) return `${two(hours)}:${two(minutes)}:${two(rest)}`;
  return `${two(minutes)}:${two(rest)}`;
}

export const elapsed = (start: number | null, end: number | null, now: number): number | null =>
  start ? (end ?? now) - start : null;

export function pathTo(p: Pipeline): Pipeline[] {
  const out: Pipeline[] = [];
  for (let cur: Pipeline | null = p; cur; cur = cur.parent) out.unshift(cur);
  return out;
}
