import { Fragment } from "preact";
import { useEffect, useRef, useState } from "preact/hooks";
import { STATUSES, STATUS_LABEL, countJobs } from "./model";
import { SearchResult, clearFilters, cursor, focusOn, hits, query, results, scope, selected, statuses, step, toggleStatus, workflow } from "./store";
import { Highlight, PipelineTitle, StatusIcon } from "./ui";

const MAX_RESULTS = 60;

const Search = () => {
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(0);
  const input = useRef<HTMLInputElement>(null);
  const r = results.value;
  const shown = r.slice(0, MAX_RESULTS);
  const current = workflow.value?.pipelineById.get(selected.value);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const t = e.target as HTMLElement;
      if ([`INPUT`, `TEXTAREA`, `SELECT`].includes(t.tagName) || t.isContentEditable || e.metaKey || e.ctrlKey || e.altKey) return;
      if (e.key === `/`) {
        e.preventDefault();
        input.current?.focus();
      } else if (e.key === `n` || e.key === `N`) {
        step(e.shiftKey ? -1 : 1);
      }
    };
    window.addEventListener(`keydown`, onKey);
    return () => window.removeEventListener(`keydown`, onKey);
  }, []);

  const choose = (x: SearchResult) => {
    focusOn(x.kind, x.id);
    setOpen(false);
    input.current?.blur();
  };

  const onKeyDown = (e: KeyboardEvent) => {
    if (e.key === `ArrowDown`) setActive(Math.min(active + 1, shown.length - 1));
    else if (e.key === `ArrowUp`) setActive(Math.max(active - 1, 0));
    else if (e.key === `Enter`) shown[active] ? choose(shown[active]) : step(1);
    else if (e.key === `Escape`) {
      setOpen(false);
      input.current?.blur();
    } else return;
    e.preventDefault();
  };

  let lastPipeline = ``;
  return (
    <div className="wf-map-search">
      <input
        ref={input}
        type="search"
        autoComplete="off"
        className="form-control w-100"
        placeholder="Find a pipeline, block or job"
        aria-label="Find a pipeline, block or job"
        value={query.value}
        onInput={(e) => {
          query.value = e.currentTarget.value;
          cursor.value = -1;
          setActive(0);
          setOpen(true);
        }}
        onFocus={() => setOpen(true)}
        onBlur={() => setTimeout(() => setOpen(false), 120)}
        onKeyDown={onKeyDown}
      />
      <kbd className="wf-map-kbd">/</kbd>
      {open && query.value.trim() && (
        <div className="wf-map-results" role="listbox" onMouseDown={(e) => e.preventDefault()}>
          <div className="wf-map-results-scope">
            <span>Search in</span>
            <div className="wf-map-seg">
              <button className={scope.value === `all` ? `on` : ``} onClick={() => (scope.value = `all`)}>
                All pipelines
              </button>
              {current && (
                <button className={scope.value === `pipeline` ? `on` : ``} onClick={() => (scope.value = `pipeline`)}>
                  <PipelineTitle p={current}/>
                </button>
              )}
            </div>
          </div>
          {shown.map((x, i) => {
            const header = x.kind !== `pipeline` && x.pipeline.id !== lastPipeline ? x.pipeline : null;
            lastPipeline = x.pipeline.id;
            return (
              <Fragment key={`${x.kind}-${x.id}`}>
                {header && (
                  <div className="wf-map-results-group">
                    <PipelineTitle p={header}/>
                  </div>
                )}
                <button role="option" aria-selected={i === active} className={`wf-map-result ${i === active ? `active` : ``}`} onMouseEnter={() => setActive(i)} onClick={() => choose(x)}>
                  <StatusIcon status={x.status} size={14}/>
                  <span className="wf-map-result-kind">{x.kind}</span>
                  <span className="wf-map-result-label">
                    <Highlight text={x.label}/>
                  </span>
                  <span className="wf-map-result-context">{x.context}</span>
                </button>
              </Fragment>
            );
          })}
          {r.length === 0 && (
            <div className="wf-map-results-note">
              Nothing named “{query.value.trim()}” {scope.value === `pipeline` ? `in this pipeline` : `in this workflow`}
              {statuses.value.size ? ` with the selected statuses` : ``}.
            </div>
          )}
          {r.length > shown.length && <div className="wf-map-results-note">{r.length - shown.length} more. Keep typing to narrow it down.</div>}
        </div>
      )}
    </div>
  );
};

const Stepper = () => {
  const h = hits.value;
  if (!h.active) return null;
  return (
    <div className="wf-map-stepper">
      <button className="btn btn-secondary btn-small" aria-label="Previous match" data-tippy-content="Previous match (Shift+N)" onClick={() => step(-1)} disabled={!h.ordered.length}>
        ‹
      </button>
      <span className="wf-map-stepper-count">{h.ordered.length ? `${cursor.value < 0 ? `–` : cursor.value + 1} of ${h.ordered.length} jobs` : `No matching jobs`}</span>
      <button className="btn btn-secondary btn-small" aria-label="Next match" data-tippy-content="Next match (N)" onClick={() => step(1)} disabled={!h.ordered.length}>
        ›
      </button>
      <button className="wf-map-link" onClick={clearFilters}>
        Clear
      </button>
    </div>
  );
};

const Chips = () => {
  const c = countJobs([...(workflow.value?.jobs.values() ?? [])]);
  return (
    <div className="wf-map-chips" role="group" aria-label="Show jobs with status">
      {STATUSES.filter((s) => c[s]).map((s) => (
        <button key={s} className={`wf-map-chip ${statuses.value.has(s) ? `on` : ``}`} aria-pressed={statuses.value.has(s)} onClick={() => toggleStatus(s)}>
          <StatusIcon status={s} size={14}/>
          {STATUS_LABEL[s]}
          <span className="wf-map-chip-count">{c[s]}</span>
        </button>
      ))}
    </div>
  );
};

export const Toolbar = () => (
  <div className="wf-map-toolbar">
    <Search/>
    <Stepper/>
    <Chips/>
  </div>
);
