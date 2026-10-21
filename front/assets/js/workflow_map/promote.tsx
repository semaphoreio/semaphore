import { signal } from "@preact/signals";
import { useEffect, useState } from "preact/hooks";
import { Pipeline, Promotion } from "./model";
import { promote } from "./store";

export const promoting = signal<{ pipeline: Pipeline, promotion: Promotion, } | null>(null);

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
    const failure = await promote(pipeline, promotion, values);
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
                  {[...new Set([param.default_value ?? ``, ...param.options])].map((option) => (
                    <option key={option} value={option}>
                      {option === `` ? `(empty)` : option}
                      {option === param.default_value && option !== `` ? ` (default)` : ``}
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
