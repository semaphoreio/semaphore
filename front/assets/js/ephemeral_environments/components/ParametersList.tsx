import { useState } from "preact/hooks";
import { MaterializeIcon } from "js/toolbox";
import * as types from "../types";
import { JSX } from "preact/jsx-runtime";

interface ParametersListProps {
  parameters: types.EnvironmentParameter[];
  onParameterAdded: (param: types.EnvironmentParameter) => void;
  onParameterUpdated: (
    paramKey: string,
    param: types.EnvironmentParameter
  ) => void;
  onParameterRemoved: (param: types.EnvironmentParameter) => void;
  disabled?: boolean;
}

export const ParametersList = (props: ParametersListProps) => {
  const {
    parameters,
    onParameterAdded,
    onParameterUpdated,
    onParameterRemoved,
    disabled,
  } = props;

  const emptyParam = { name: ``, description: ``, required: false };

  const [newParam, setNewParam] =
    useState<types.EnvironmentParameter>(emptyParam);

  return (
    <div>
      <div className="mb3 ba b--black-10 br2 pa2 bg-near-white mb2 flex flex-column gap-2">
        {parameters.length === 0 && (
          <p className="ma0 gray lh-copy tc">
            No context variables defined yet.
          </p>
        )}
        {parameters.map((param, index) => (
          <div key={index} className="ba b--black-10 br2 pa2 bg-white">
            <div className="flex items-center gap-2">
              <ParameterForm
                className="flex items-center gap-2 flex-1"
                param={param}
                onParamChange={(updatedParam) =>
                  onParameterUpdated(param.name, updatedParam)
                }
                disabled={disabled}
              />
              {!disabled && (
                <button
                  type="button"
                  className="btn btn-danger inter flex items-center"
                  onClick={() => onParameterRemoved(param)}
                >
                  <MaterializeIcon name="delete" className="mr1 white"/>
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
            <ParameterForm
              className="flex items-center gap-2 flex-1"
              param={newParam}
              onParamChange={setNewParam}
            />
            <button
              type="button"
              className="btn btn-secondary flex items-center"
              onClick={() => {
                onParameterAdded(newParam);
                setNewParam(emptyParam);
              }}
              disabled={!newParam.name.trim()}
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

interface ParameterFormProps
  extends Partial<JSX.HTMLAttributes<HTMLDivElement>> {
  param: types.EnvironmentParameter;
  onParamChange: (param: types.EnvironmentParameter) => void;
  disabled?: boolean;
}
const ParameterForm = ({
  param,
  onParamChange,
  disabled,
  ...restProps
}: ParameterFormProps) => {
  return (
    <div {...restProps}>
      <input
        type="text"
        className="form-control pa1 w-30"
        placeholder="Parameter name"
        value={param.name}
        onChange={(e) =>
          onParamChange({
            ...param,
            name: (e.target as HTMLInputElement).value,
          })
        }
        disabled={disabled}
      />

      <input
        type="text"
        className="form-control pa1 flex-1"
        placeholder="Description"
        value={param.description}
        onChange={(e) =>
          onParamChange({
            ...param,
            description: (e.target as HTMLInputElement).value,
          })
        }
        disabled={disabled}
      />

      <label className="flex items-center">
        <input
          type="checkbox"
          checked={param.required || false}
          onChange={(e) =>
            onParamChange({
              ...param,
              required: (e.target as HTMLInputElement).checked,
            })
          }
          className="mr1"
          disabled={disabled}
        />
        Required
      </label>
    </div>
  );
};
