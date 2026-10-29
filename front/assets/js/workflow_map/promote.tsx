import { signal } from "@preact/signals";
import { useEffect, useState } from "preact/hooks";
import { Pipeline, Promotion } from "./model";
import { popover, promote, togglePopover } from "./store";

export const promoting = signal<{ pipeline: Pipeline, promotion: Promotion, } | null>(null);

export const PromoteButton = ({ p, compact }: { p: Pipeline, compact?: boolean, }) => {
  if (!p.promotions?.length) return null;
  const fresh = p.promotions.filter((promotion) => !promotion.events.length).length;
  return (
    <button
      className="btn btn-primary btn-tiny wf-map-promote"
      data-popover-trigger=""
      aria-haspopup="menu"
      aria-expanded={popover.value?.kind === `promote` && popover.value.id === p.id}
      aria-label={compact ? `Promote ${p.name}` : undefined}
      data-tippy-content={fresh ? `Promote: ${fresh} of ${p.promotions.length} promotions not run yet` : `Promote: all ${p.promotions.length} promotions have run`}
      onClick={(e) => togglePopover(`promote`, p.id, e.currentTarget)}
    >
      {compact ? <span className="material-symbols-outlined" aria-hidden="true">rocket_launch</span> : `Promote ▾`}
      {fresh > 0 && <span className="wf-map-promote-count">{fresh}</span>}
    </button>
  );
};

export const Promotions = ({ p }: { p: Pipeline, }) => (
  <div role="menu" aria-label={`Promotions of ${p.name}`}>
    {p.promotions?.map((promotion) => {
      const latest = promotion.events.reduce((a, e) => (!a || e.triggered_at > a.triggered_at ? e : a), null);
      const note = promotion.starting
        ? `Starting promotion…`
        : !latest
          ? `Not promoted yet`
          : latest.processed && latest.result === `FAILED`
            ? `Failed to promote`
            : `${promotion.events.length > 1 ? `${promotion.events.length}× · ` : ``}${latest.auto ? `auto-promoted` : `by ${latest.author ?? `someone`}`}`;
      const blocked = promotion.deployment && !promotion.deployment.allowed;
      const why = blocked ? promotion.deployment.message ?? `Blocked by the ${promotion.deployment.name} deployment target` : `You don't have permission to promote`;
      return (
        <div key={promotion.name} className="wf-map-promotion" role="menuitem">
          <span className="material-symbols-outlined wf-map-promotion-icon" aria-hidden="true">
            {promotion.deployment ? (promotion.deployment.allowed ? `lock_open` : `lock`) : `rocket_launch`}
          </span>
          <span className="wf-map-promotion-text">
            <span className="wf-map-promotion-name">{promotion.name}</span>
            <span className={`wf-map-promotion-note ${latest?.result === `FAILED` ? `failed` : ``} ${latest ? `` : `fresh`}`}>{blocked ? promotion.deployment.name : note}</span>
          </span>
          <button
            className="btn btn-secondary btn-small"
            disabled={!promotion.can_promote || promotion.starting}
            title={promotion.can_promote ? `Promote ${p.name} to ${promotion.name}` : why}
            onClick={() => {
              popover.value = null;
              promoting.value = { pipeline: p, promotion };
            }}
          >
            Promote
          </button>
        </div>
      );
    })}
  </div>
);

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
