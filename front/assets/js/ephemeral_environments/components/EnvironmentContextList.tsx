import { useState } from "preact/hooks";
import { MaterializeIcon } from "js/toolbox";
import * as types from "../types";
import { JSX } from "preact/jsx-runtime";

interface EnvironmentContextListProps {
  contexts: types.EnvironmentContext[];
  onContextAdded: (context: types.EnvironmentContext) => void;
  onContextRemoved: (context: types.EnvironmentContext) => void;
  onContextUpdated: (
    contextKey: string,
    context: types.EnvironmentContext
  ) => void;
  disabled?: boolean;
}

export const EnvironmentContextList = ({
  contexts,
  onContextAdded,
  onContextRemoved,
  onContextUpdated,
  disabled = false,
}: EnvironmentContextListProps) => {
  const emptyContext = { name: ``, description: `` };
  const [newContext, setNewContext] =
    useState<types.EnvironmentContext>(emptyContext);

  return (
    <div>
      <div className="mb3">
        <div className="flex items-center mb2">
          <MaterializeIcon name="language" className="mr2 blue"/>
          <span className="fw6">Environment Context Variables</span>
        </div>
        <p className="ma0 gray lh-copy mb3">
          These context variables are set during provisioning and are available
          globally to all stages of the environment lifecycle.
        </p>
      </div>

      <div className="mb3 ba b--black-10 br2 pa2 bg-near-white mb2 flex flex-column gap-2">
        {contexts.length === 0 && (
          <p className="ma0 gray lh-copy tc">
            No context variables defined yet.
          </p>
        )}
        {contexts.map((context, index) => (
          <div key={index} className="ba b--black-10 br2 pa2 bg-white">
            <div className="flex items-center gap-2">
              <ContextForm
                className={`flex items-center gap-2 flex-1`}
                onContextChange={(updatedContext) =>
                  onContextUpdated(context.name, updatedContext)
                }
                context={context}
              />
              {!disabled && (
                <button
                  type="button"
                  className="btn btn-danger flex items-center"
                  onClick={() => onContextRemoved(context)}
                >
                  <MaterializeIcon name="delete" className="mr1"/>
                  Remove
                </button>
              )}
            </div>
          </div>
        ))}
      </div>

      {!disabled && (
        <div className="ba b--black-10 br2 pa3 bg-white">
          <div className="flex items-center gap-2">
            <ContextForm
              className={`flex items-center gap-2 flex-1`}
              onContextChange={setNewContext}
              context={newContext}
            />

            <button
              type="button"
              className="btn btn-secondary btn-small flex items-center"
              onClick={() => {
                onContextAdded(newContext);
                setNewContext(emptyContext);
              }}
              disabled={!newContext.name.trim()}
            >
              <MaterializeIcon name="add" className="mr1"/>
              Add
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

interface ContextFormProps extends Partial<JSX.HTMLAttributes<HTMLDivElement>> {
  context: types.EnvironmentContext;
  onContextChange: (context: types.EnvironmentContext) => void;
  disabled?: boolean;
}

const ContextForm = ({
  context,
  onContextChange,
  disabled,
  ...restProps
}: ContextFormProps) => {
  return (
    <div {...restProps}>
      <input
        type="text"
        className="form-control pa1 w-30"
        placeholder="New context variable name"
        value={context.name}
        onChange={(e) =>
          onContextChange({
            ...context,
            name: (e.target as HTMLInputElement).value,
          })
        }
        disabled={disabled}
      />
      <input
        type="text"
        className="form-control pa1 flex-1"
        placeholder="Description"
        value={context.description}
        onChange={(e) =>
          onContextChange({
            ...context,
            description: (e.target as HTMLInputElement).value,
          })
        }
        disabled={disabled}
      />
    </div>
  );
};
