import { Block } from "./model";

export const BLOCK = { w: 230, h: 74 };
export const OPEN_BLOCK_W = 260;
export const BLOCK_HEAD_H = 40;
export const JOB_ROW_H = 23;

export const jobTop = (index: number) => BLOCK_HEAD_H + index * JOB_ROW_H;

export const blockSize = (b: Block, open: boolean) => (open ? { w: OPEN_BLOCK_W, h: jobTop(b.jobs.length) + 8 } : BLOCK);
