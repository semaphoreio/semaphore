import { signal } from "@preact/signals";
import { useEffect, useRef, useState } from "preact/hooks";
import { Pipeline, Promotion, formatAgo, shortName } from "./model";
import { focusOn, now, popover, promote, togglePopover } from "./store";
import { Duration, Name, StatusIcon, TimeAgo } from "./ui";

export const promoting = signal<{ pipeline: Pipeline, promotion: Promotion, } | null>(null);

export const PromoteButton = ({ p, compact }: { p: Pipeline, compact?: boolean, }) => {
  if (!p.promotions?.length) return null;
  const n = p.promotions.length;
  return (
    <button
      className="btn btn-primary btn-tiny wf-map-promote"
      data-popover-trigger=""
      aria-haspopup="menu"
      aria-expanded={popover.value?.kind === `promote` && popover.value.id === p.id}
      aria-label={compact ? `Promote ${p.name}` : undefined}
      data-tippy-content={`Promote: ${n} ${n === 1 ? `promotion` : `promotions`}`}
      onClick={(e) => togglePopover(`promote`, p.id, e.currentTarget)}
    >
      {compact ? <span className="material-symbols-outlined" aria-hidden="true">rocket_launch</span> : `Promote ▾`}
    </button>
  );
};

export const Promotions = ({ p }: { p: Pipeline, }) => {
  const [filter, setFilter] = useState(``);
  const input = useRef<HTMLInputElement>(null);
  useEffect(() => input.current?.focus(), []);
  const q = filter.trim().toLowerCase();
  const runText = (run: Pipeline) => [run.name, ...run.parameters.map((v) => `${v.name}=${v.value}`)].join(` `).toLowerCase();
  const shown = p.promotions?.filter((promotion) => promotion.name.toLowerCase().includes(q) || promotion.pipelines.some((run) => runText(run).includes(q))) ?? [];
  return (
    <div role="menu" aria-label={`Promotions of ${p.name}`}>
      <input
        ref={input}
        type="text"
        className="form-control form-control-small wf-map-promotion-filter"
        placeholder="Filter promotions and runs"
        aria-label="Filter promotions"
        value={filter}
        onInput={(e) => setFilter(e.currentTarget.value)}
        onKeyDown={(e) => {
          if (e.key === `Enter`) e.preventDefault();
          if (e.key === `Escape` && filter) {
            e.preventDefault();
            e.stopPropagation();
            setFilter(``);
          }
        }}
      />
      {!shown.length && <p className="wf-map-promotion-none">No promotion matches “{filter.trim()}”</p>}
      {shown.map((promotion) => {
        const latest = promotion.events.reduce((a, e) => (!a || e.triggered_at > a.triggered_at ? e : a), null);
        const runs = [...promotion.pipelines].sort((a, b) => (b.createdAt ?? 0) - (a.createdAt ?? 0));
        const note = promotion.starting
          ? `Starting promotion…`
          : !latest
            ? null
            : latest.processed && latest.result === `FAILED`
              ? `Failed to promote`
              : runs.length ? null : latest.auto ? `Auto-promoted` : shortName(latest.author ?? `Someone`);
        const why = !promotion.can_promote && (promotion.deployment && !promotion.deployment.allowed
          ? promotion.deployment.message ?? `Blocked by the ${promotion.deployment.name} deployment target`
          : `You don't have permission to promote`);
        return (
          <div key={promotion.name} className="wf-map-promotion-group">
            <div className="wf-map-promotion" role="menuitem">
              <span className="material-symbols-outlined wf-map-promotion-icon" aria-hidden="true">
                {promotion.deployment ? (promotion.deployment.allowed ? `lock_open` : `lock`) : `rocket_launch`}
              </span>
              <span className="wf-map-promotion-text">
                <Name className="wf-map-promotion-name">{promotion.name}</Name>
                {note && (
                  <span className={`wf-map-promotion-note ${latest?.result === `FAILED` ? `failed` : ``}`} title={latest?.author ?? undefined}>
                    {note}
                    {latest && !promotion.starting && (
                      <>
                        {` · `}
                        <TimeAgo at={latest.triggered_at}/>
                      </>
                    )}
                  </span>
                )}
                {why && <span className="wf-map-promotion-note blocked">{why}</span>}
              </span>
              <button
                className="btn btn-secondary btn-small"
                disabled={!promotion.can_promote || promotion.starting}
                title={why || `Promote ${p.name} to ${promotion.name}`}
                onClick={() => {
                  popover.value = null;
                  promoting.value = { pipeline: p, promotion };
                }}
              >
              Promote
              </button>
            </div>
            {runs.length > 0 && (
              <ul className="wf-map-runs" aria-label={`Runs of ${promotion.name}`}>
                {runs.map((run) => {
                  const params = run.parameters.filter((v) => v.value).sort((a, b) => (a.name < b.name ? -1 : 1));
                  return (
                    <li key={run.id}>
                      <a
                        className="wf-map-run"
                        href={`?pipeline_id=${run.id}`}
                        title={`Show ${run.name} on the map`}
                        onClick={(e) => {
                          if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
                          e.preventDefault();
                          popover.value = null;
                          focusOn(`pipeline`, run.id);
                        }}
                      >
                        <StatusIcon status={run.status} size={14}/>
                        <span className="wf-map-run-text">
                          <span className="wf-map-run-name">
                            {run.name}
                            {run.attempt > 1 && <span className="wf-map-attempt">#{run.attempt}</span>}
                          </span>
                          {params.length > 0 && (
                            <span className="wf-map-run-params">
                              {params.map((v) => <span key={v.name}>{v.name}={v.value}</span>)}
                            </span>
                          )}
                        </span>
                        <Duration start={run.runningAt} end={run.doneAt} running={run.status === `running`}/>
                        <span className="wf-map-run-ago">{run.createdAt && formatAgo(now.value - run.createdAt)}</span>
                      </a>
                    </li>
                  );
                })}
              </ul>
            )}
          </div>
        );
      })}
    </div>
  );
};

const PromoteForm = ({ pipeline, promotion }: { pipeline: Pipeline, promotion: Promotion, }) => {
  const [values, setValues] = useState<Record<string, string>>(() => Object.fromEntries(promotion.parameters.map((p) => [p.name, p.default_value ?? ``])));
  const [error, setError] = useState<string | null>(null);
  const [sending, setSending] = useState(false);
  const close = () => {
    promoting.value = null;
  };

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === `Escape`) close();
    };
    document.addEventListener(`keydown`, onKey);
    return () => document.removeEventListener(`keydown`, onKey);
  }, []);

  const submit = async (e: Event) => {
    e.preventDefault();
    const missing = promotion.parameters.filter((p) => p.required && !values[p.name]?.trim()).map((p) => p.name);
    if (missing.length) return setError(`Fill in ${missing.join(`, `)} first.`);
    setSending(true);
    const sent = promotion.parameters.filter((p) => values[p.name] !== `` || !p.options.length).map((p): [string, string] => [p.name, values[p.name]]);
    const failure = await promote(pipeline, promotion, Object.fromEntries(sent));
    setSending(false);
    if (failure) setError(failure);
    else close();
  };

  return (
    <div className="wf-map-dialog-backdrop" onClick={(e) => {
      if (e.target === e.currentTarget) close();
    }}>
      <form className="wf-map-dialog" role="dialog" aria-label={`Promote to ${promotion.name}`} onSubmit={(e) => void submit(e)}>
        <h3 className="wf-map-dialog-title">Promote to {promotion.name}?</h3>
        <p className="wf-map-dialog-from">From {pipeline.name}</p>
        {promotion.parameters.map((param) => {
          const id = `wf-map-param-${param.name}`;
          const set = (value: string) => setValues({ ...values, [param.name]: value });
          return (
            <div className="wf-map-dialog-field" key={param.name}>
              <div className="flex justify-between items-baseline">
                <label htmlFor={id} className="db f6 b mb1">
                  {param.name}
                </label>
                <small className="f7 gray">{param.required ? `required` : `optional`}</small>
              </div>
              {param.options.length ? (
                <select id={id} className="form-control form-control-small w-100" value={values[param.name]} onChange={(e) => set(e.currentTarget.value)}>
                  {!param.default_value && (
                    <option value="" disabled>
                      Select an option
                    </option>
                  )}
                  {[...new Set([param.default_value, ...param.options].filter(Boolean))].map((option) => (
                    <option key={option} value={option}>
                      {option}
                      {option === param.default_value ? ` (default)` : ``}
                    </option>
                  ))}
                </select>
              ) : (
                <input id={id} type="text" className="form-control form-control-small w-100" value={values[param.name]} onInput={(e) => set(e.currentTarget.value)}/>
              )}
              {param.description && <p className="f7 gray mt1 mb0">{param.description}</p>}
            </div>
          );
        })}
        {error && <p className="wf-map-dialog-error">{error}</p>}
        <div className="wf-map-dialog-actions">
          <button type="submit" className="btn btn-primary btn-small" disabled={sending}>
            {sending ? `Starting promotion…` : `Start promotion`}
          </button>
          <button type="button" className="btn btn-secondary btn-small" onClick={close}>
            Cancel
          </button>
        </div>
      </form>
    </div>
  );
};

export const PromoteDialog = () => {
  const target = promoting.value;
  return target ? <PromoteForm key={`${target.pipeline.id}/${target.promotion.name}`} pipeline={target.pipeline} promotion={target.promotion}/> : null;
};
