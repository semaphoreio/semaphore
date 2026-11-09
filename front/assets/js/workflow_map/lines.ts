import { Block, Job, blockSummary } from "./model";

export const BLOCK = { w: 230, h: 74 };
export const OPEN_BLOCK_W = 260;
export const BLOCK_HEAD_H = 40;
const HEAD_H = 30;
export const JOB_ROW_H = 23;
export const NAME_LINE_H = 18;
export const JOB_LINE_H = 16;
export const META_LINE_H = 14;

const FIT = {
  summary: { weight: 500, size: 0, width: BLOCK.w - 2 * 12 - 16 - 8 },
  head: { weight: 500, size: 0, width: OPEN_BLOCK_W - 2 * 8 - 16 - 8 },
  job: { weight: 400, size: 13, width: OPEN_BLOCK_W - 2 * 8 - 14 - 2 * 8 - 46 },
  meta: { weight: 400, size: 12, width: BLOCK.w - 2 * 12 },
};

const measured = new Map<string, 1 | 2>();
let ctx: OffscreenCanvasRenderingContext2D | null | undefined;

export const nameLines = (text: string, kind: keyof typeof FIT): 1 | 2 => {
  const key = `${kind}|${text}`;
  const known = measured.get(key);
  if (known) return known;
  if (ctx === undefined) ctx = typeof OffscreenCanvas === `undefined` ? null : new OffscreenCanvas(1, 1).getContext(`2d`);
  const root = document.querySelector(`.wf-map`) ?? document.body;
  const style = getComputedStyle(root);
  const f = FIT[kind];
  const size = f.size || parseFloat(style.fontSize) || 14;
  let width = text.length * size * 0.55;
  if (ctx) {
    ctx.font = `${f.weight} ${size}px ${style.fontFamily || `sans-serif`}`;
    width = ctx.measureText(text).width;
  }
  const lines = width > f.width ? 2 : 1;
  measured.set(key, lines);
  return lines;
};

export const headHeight = (b: Block) => HEAD_H + (nameLines(b.name, `head`) - 1) * NAME_LINE_H;

export const jobRowHeight = (j: Job) => JOB_ROW_H + (nameLines(j.name, `job`) - 1) * JOB_LINE_H;

export const jobTop = (b: Block, index: number) =>
  BLOCK_HEAD_H + headHeight(b) - HEAD_H + b.jobs.slice(0, index).reduce((sum, j) => sum + jobRowHeight(j), 0);

export const blockSize = (b: Block, open: boolean) =>
  open
    ? { w: OPEN_BLOCK_W, h: jobTop(b, b.jobs.length) + 8 }
    : { w: BLOCK.w, h: BLOCK.h + (nameLines(b.name, `summary`) - 1) * NAME_LINE_H + (nameLines(blockSummary(b), `meta`) - 1) * META_LINE_H };
