import { Block, Job } from "./model";

export const BLOCK = { w: 230, h: 74 };
export const OPEN_BLOCK_W = 260;
export const WIDE_BLOCK_W = 420;
export const BLOCK_HEAD_H = 40;
export const JOB_ROW_H = 23;
export const GROUP_ROW_H = 22;
export const BLOCK_GAP = 24;
const LINE_H = 16;
const MAX_LINES = 3;
const NAME_ROOM = 124;
const MATRIX = /^(.+?) - ([A-Za-z_]\w*=.*)$/;

export interface Row { top: number, h: number, text: string, job?: Job, }

let ctx: CanvasRenderingContext2D | null | undefined;
const textWidth = (text: string) => {
  if (ctx === undefined) {
    ctx = document.createElement(`canvas`).getContext?.(`2d`) ?? null;
    if (ctx) ctx.font = `13px ${getComputedStyle(document.body).fontFamily}`;
  }
  return ctx ? ctx.measureText(text).width : text.length * 7;
};

export function lineCount(text: string, room: number) {
  let n = 1;
  let line = 0;
  for (const word of text.split(/(?<=[\s-])/)) {
    const w = textWidth(word);
    if (line && line + w > room) n++, (line = 0);
    line += w;
    while (line > room) n++, (line -= room);
  }
  return Math.min(n, MAX_LINES);
}

export function jobRows(b: Block): { w: number, rows: Row[], } {
  const base = (j: Job) => MATRIX.exec(j.name)?.[1];
  const shared = new Set(b.jobs.map(base).filter((x, i, all) => x && all.indexOf(x) !== i));
  const groups = new Map<string, Job[]>();
  for (const j of b.jobs) {
    const key = shared.has(base(j)) ? base(j) : ``;
    groups.set(key, [...(groups.get(key) ?? []), j]);
  }
  const items: { text: string, job?: Job, }[] = [...groups].flatMap(([group, jobs]) => {
    if (!group) return jobs.map((job) => ({ job, text: job.name }));
    const envs = jobs.map((j) => MATRIX.exec(j.name)[2].split(/, (?=[A-Za-z_]\w*=)/).map((kv) => [kv.slice(0, kv.indexOf(`=`)), kv.slice(kv.indexOf(`=`) + 1)]));
    const keys = envs[0].map(([k]) => k).join(`, `);
    const same = envs.every((env) => env.map(([k]) => k).join(`, `) === keys);
    return [
      { text: same ? `${group} · ${keys}` : group },
      ...jobs.map((job, i) => ({ job, text: same ? envs[i].map(([, v]) => v).join(` · `) : MATRIX.exec(job.name)[2] })),
    ];
  });
  const wide = items.some((r) => r.job && lineCount(r.text, OPEN_BLOCK_W - NAME_ROOM) > 1);
  const w = wide ? WIDE_BLOCK_W : OPEN_BLOCK_W;
  let top = BLOCK_HEAD_H;
  const rows = items.map((r) => {
    const h = r.job ? JOB_ROW_H + (lineCount(r.text, w - NAME_ROOM) - 1) * LINE_H : GROUP_ROW_H;
    const row = { ...r, top, h };
    top += h;
    return row;
  });
  return { w, rows };
}

export const jobRow = (b: Block, index: number) => jobRows(b).rows.find((r) => r.job === b.jobs[index]);

export const blockSize = (b: Block, open: boolean) => {
  if (!open) return BLOCK;
  const { w, rows } = jobRows(b);
  const last = rows[rows.length - 1];
  return { w, h: (last ? last.top + last.h : BLOCK_HEAD_H) + 8 };
};
