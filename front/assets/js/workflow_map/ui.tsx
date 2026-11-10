import { ComponentChildren } from "preact";
import { useState } from "preact/hooks";
import { Block, Job, Pipeline, STATUSES, STATUS_LABEL, Status, blockStatus, blockSummary, countJobs, formatDuration } from "./model";
import { focus, hits, now, query } from "./store";

export const StatusIcon = ({ status, size = 16 }: { status: Status, size?: number, }) => {
  const fill = { style: { fill: `var(--wf-map-${status})` } };
  const glyph = { style: { fill: `#fff` } };
  return (
    <svg className="wf-map-icon" width={size} height={size} viewBox="0 0 16 16" role="img" aria-label={STATUS_LABEL[status]}>
      {status === `pending` ? (
        <path {...fill} d="M8 0c4.418 0 8 3.59 8 8 0 4.418-3.59 8-8 8-4.418 0-8-3.59-8-8 0-4.418 3.59-8 8-8zM2 8c0 3.308 2.69 6 6 6 3.308 0 6-2.69 6-6 0-3.308-2.69-6-6-6-3.308 0-6 2.69-6 6z"/>
      ) : (
        <circle {...fill} cx="8" cy="8" r="8"/>
      )}
      {status === `passed` && <path {...glyph} d="M7.456 8.577L6.273 7.45a1 1 0 00-1.38 1.448l1.917 1.826a1 1 0 001.423-.044l3.386-3.652a1 1 0 00-1.466-1.36z"/>}
      {status === `failed` && <path {...glyph} d="M5.293 6.707l4 4a1 1 0 101.414-1.414l-4-4a1 1 0 00-1.414 1.414zM5.293 9.293l4-4a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414-1.414z"/>}
      {status === `stopped` && <path {...glyph} d="M5.994 9l4.023.023a1 1 0 00.011-2L6.006 7a1 1 0 00-.012 2z"/>}
      {status === `running` && (
        <g {...glyph}>
          <circle cx="5" cy="8" r="1"/>
          <circle cx="8" cy="8" r="1"/>
          <circle cx="11" cy="8" r="1"/>
        </g>
      )}
      {status === `queued` && (
        <g {...glyph}>
          <rect height="4" rx="1" width="2" x="3" y="5"/>
          <rect height="4" rx="1" width="2" x="7" y="6"/>
          <rect height="4" rx="1" width="2" x="11" y="7"/>
        </g>
      )}
      {status === `skipped` && <path {...glyph} d="M4 5l3.5 3L4 11zm5 0l3.5 3L9 11z"/>}
    </svg>
  );
};

export const Highlight = ({ text }: { text: string, }) => {
  const q = query.value.trim();
  const i = q ? text.toLowerCase().indexOf(q.toLowerCase()) : -1;
  if (i < 0) return <>{text}</>;
  return (
    <>
      {text.slice(0, i)}
      <mark>{text.slice(i, i + q.length)}</mark>
      {text.slice(i + q.length)}
    </>
  );
};

export const DOUBLE_CLICK_MS = 300;
let pending: number | undefined;
let down = { x: 0, y: 0 };
document.addEventListener(`pointerdown`, (e) => (down = { x: e.clientX, y: e.clientY }), true);

export const plainClick = (e: MouseEvent, act: (el: Element) => void) => {
  window.clearTimeout(pending);
  const el = e.currentTarget as Element;
  const s = window.getSelection();
  const moved = e.detail > 0 && (Math.abs(e.clientX - down.x) > 3 || Math.abs(e.clientY - down.y) > 3);
  if (e.detail > 1 || moved || (s && !s.isCollapsed && el.contains(s.anchorNode))) return;
  if ((e.target as Element).closest(`.wf-map-name`)) pending = window.setTimeout(() => act(el), DOUBLE_CLICK_MS);
  else act(el);
};

export const COPIED_MS = 1500;

const CopyName = () => {
  const [copied, setCopied] = useState(false);
  return (
    <span
      role="button"
      className={`wf-map-copy ${copied ? `copied` : ``}`}
      aria-label={copied ? `Copied` : `Copy the name`}
      onPointerDown={(e) => e.stopPropagation()}
      onClick={(e) => {
        e.stopPropagation();
        e.preventDefault();
        void navigator.clipboard.writeText(e.currentTarget.parentElement.textContent).then(() => {
          setCopied(true);
          window.setTimeout(() => setCopied(false), COPIED_MS);
        });
      }}
    >
      <svg viewBox="0 0 16 16" width="12" height="12" aria-hidden="true">
        {copied ? (
          <path d="M13.8 3.7 6 11.5 2.2 7.7l1-1L6 9.4l6.8-6.8z"/>
        ) : (
          <path d="M5 1h8a1 1 0 0 1 1 1v9h-1.5V2.5H5zM3 4h7a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1zm.5 1.5v8h6v-8z"/>
        )}
      </svg>
    </span>
  );
};

export const Name = ({ className = ``, children }: { className?: string, children: ComponentChildren, }) => (
  <span className={`wf-map-name nopan nodrag ${className}`}>
    <span className="wf-map-name-text">
      {children}
      <CopyName/>
    </span>
  </span>
);

export const Chevron = ({ open }: { open: boolean, }) => (
  <svg className={`wf-map-chevron ${open ? `open` : ``}`} viewBox="0 0 16 16" width="12" height="12" aria-hidden="true">
    <path d="M6 3.5 10.5 8 6 12.5" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
  </svg>
);

export const Duration = ({ start, end, running }: { start: number | null, end: number | null, running: boolean, }) => {
  const seconds = start ? (end ?? (running ? now.value : start)) - start : null;
  return <span className="wf-map-time">{seconds === null ? `--:--` : formatDuration(seconds)}</span>;
};

export const JobRow = ({ job }: { job: Job, }) => {
  const h = hits.value;
  const f = focus.value;
  const flash = f?.kind === `job` && f.id === job.key;
  const cls = [`wf-map-job`, h.active && !h.jobs.has(job) ? `dim` : ``, h.active && h.jobs.has(job) ? `hit` : ``, flash ? `flash` : ``].join(` `);
  const body = (
    <>
      <StatusIcon status={job.status} size={14}/>
      <Name className="wf-map-job-name">
        <Highlight text={job.name}/>
      </Name>
      {job.reused ? <span className="wf-map-time">reused</span> : <Duration start={job.startedAt} end={job.finishedAt} running={job.status === `running`}/>}
    </>
  );
  return job.id ? (
    <a className={cls} href={`/jobs/${job.id}`} draggable={false} key={flash ? `${job.key}:${f.seq}` : job.key} onClick={(e) => e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || (e.preventDefault(), plainClick(e, () => window.location.assign(`/jobs/${job.id}`)))}>
      {body}
    </a>
  ) : (
    <div className={cls} key={job.key}>
      {body}
    </div>
  );
};

export const StatusBar = ({ jobs }: { jobs: Job[], }) => {
  const c = countJobs(jobs);
  const present = STATUSES.filter((s) => c[s]);
  return (
    <span className="wf-map-bar" role="img" aria-label={present.map((s) => `${c[s]} ${STATUS_LABEL[s].toLowerCase()}`).join(`, `)}>
      {present.map((s) => (
        <span key={s} className={`wf-map-bar-${s}`} style={{ flexGrow: c[s], backgroundColor: `var(--wf-map-${s})` }}/>
      ))}
    </span>
  );
};

export const AFTER_INFO = `Runs after the pipeline completes`;

const AfterInfo = () => (
  <span
    className="material-symbols-outlined wf-map-after-info"
    role="img"
    aria-label={AFTER_INFO}
    data-tippy-content={AFTER_INFO}
    onClick={(e) => e.stopPropagation()}
  >
    info
  </span>
);

export const BlockSummary = ({ block, onClick }: { block: Block, onClick: () => void, }) => {
  const f = focus.value;
  return (
    <button className={`wf-map-summary ${f && (f.id === block.id || f.id.startsWith(`${block.id}#`)) ? `focused` : ``}`} aria-expanded={false} onClick={(e) => plainClick(e, onClick)}>
      <span className="wf-map-summary-name">
        <Chevron open={false}/>
        <StatusIcon status={blockStatus(block)}/>
        <Name className="wf-map-block-name">
          <Highlight text={block.name}/>
        </Name>
        {block.after && <AfterInfo/>}
      </span>
      <StatusBar jobs={block.jobs}/>
      <span className="wf-map-summary-meta">{blockSummary(block)}</span>
    </button>
  );
};

export const BlockCard = ({ block, onHeaderClick }: { block: Block, onHeaderClick?: () => void, }) => {
  const h = hits.value;
  const f = focus.value;
  const focused = f && (f.id === block.id || f.id.startsWith(`${block.id}#`));
  const st = blockStatus(block);
  return (
    <div className={`wf-map-block ${h.active && !h.blocks.has(block) ? `dim` : ``} ${focused ? `focused` : ``}`}>
      <button className="wf-map-block-head" aria-expanded={true} onClick={(e) => plainClick(e, () => onHeaderClick?.())}>
        <Chevron open/>
        <StatusIcon status={st}/>
        <Name className="wf-map-block-name">
          <Highlight text={block.name}/>
        </Name>
        {block.after && <AfterInfo/>}
      </button>
      {block.jobs.map((j) => (
        <JobRow key={j.key} job={j}/>
      ))}
    </div>
  );
};

export const PipelineTitle = ({ p }: { p: Pipeline, }) => (
  <span className="wf-map-title">
    <Name className="wf-map-title-name">
      <Highlight text={p.name}/>
    </Name>
    {p.attempt > 1 && <span className="wf-map-attempt">#{p.attempt}</span>}
  </span>
);

export const Counts = ({ jobs }: { jobs: Job[], }) => {
  const c = countJobs(jobs);
  return (
    <span className="wf-map-counts">
      {([`failed`, `running`, `queued`, `stopped`] as Status[])
        .filter((s) => c[s])
        .map((s) => (
          <span key={s} className="wf-map-count" title={`${c[s]} ${STATUS_LABEL[s].toLowerCase()}`}>
            <StatusIcon status={s} size={12}/>
            {c[s]}
          </span>
        ))}
    </span>
  );
};
