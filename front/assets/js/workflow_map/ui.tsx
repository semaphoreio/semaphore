import { Block, Job, Pipeline, STATUSES, STATUS_LABEL, Status, blockStatus, countJobs, formatDuration } from "./model";
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
      <span className="wf-map-job-name">
        <Highlight text={job.name}/>
      </span>
      {job.reused ? <span className="wf-map-time">reused</span> : <Duration start={job.startedAt} end={job.finishedAt} running={job.status === `running`}/>}
    </>
  );
  return job.id ? (
    <a className={cls} href={`/jobs/${job.id}`} key={flash ? `${job.key}:${f.seq}` : job.key}>
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

export const BlockCard = ({ block, onHeaderClick }: { block: Block, onHeaderClick?: () => void, }) => {
  const h = hits.value;
  const f = focus.value;
  const focused = f && (f.id === block.id || f.id.startsWith(`${block.id}#`));
  const st = blockStatus(block);
  return (
    <div className={`wf-map-block ${h.active && !h.blocks.has(block) ? `dim` : ``} ${focused ? `focused` : ``}`}>
      <button className="wf-map-block-head" onClick={onHeaderClick} data-tippy-content="Collapse block">
        <StatusIcon status={st}/>
        <span className="wf-map-block-name">
          <Highlight text={block.name}/>
        </span>
      </button>
      {block.jobs.map((j) => (
        <JobRow key={j.key} job={j}/>
      ))}
    </div>
  );
};

export const PipelineTitle = ({ p }: { p: Pipeline, }) => (
  <span className="wf-map-title">
    <Highlight text={p.name}/>
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
