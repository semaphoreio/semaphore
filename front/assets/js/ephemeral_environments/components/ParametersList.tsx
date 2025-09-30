import { useState } from "preact/hooks";
import { MaterializeIcon } from "js/toolbox";
import * as types from "../types";

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
  const [isAddingNew, setIsAddingNew] = useState(false);

  return (
    <div>
      {parameters.length === 0 && !isAddingNew && (
        <p className="ma0 gray lh-copy tc mb3">
          No parameters defined yet.
        </p>
      )}

      <div className="flex flex-column gap-2 mb3">
        {parameters.map((param, index) => (
          <CollapsibleParameter
            key={index}
            param={param}
            onParamUpdated={(updatedParam) =>
              onParameterUpdated(param.name, updatedParam)
            }
            onParamRemoved={() => onParameterRemoved(param)}
            disabled={disabled}
          />
        ))}
      </div>

      {!disabled && !isAddingNew && (
        <button
          type="button"
          className="btn btn-secondary flex items-center"
          onClick={() => setIsAddingNew(true)}
        >
          <MaterializeIcon name="add" className="mr1"/>
          Add Parameter
        </button>
      )}

      {!disabled && isAddingNew && (
        <div className="ba b--black-10 br2 pa3 bg-white mb2">
          <div className="mb2">
            <label className="db fw6 mb1">Parameter Name *</label>
            <input
              type="text"
              className="form-control pa2 w-100"
              placeholder="e.g., DATABASE_URL"
              value={newParam.name}
              onChange={(e) =>
                setNewParam({
                  ...newParam,
                  name: (e.target as HTMLInputElement).value,
                })
              }
            />
          </div>

          <div className="mb2">
            <label className="db fw6 mb1">Description</label>
            <textarea
              className="form-control pa2 w-100"
              placeholder="What is this parameter used for?"
              value={newParam.description}
              rows={2}
              onChange={(e) =>
                setNewParam({
                  ...newParam,
                  description: (e.target as HTMLTextAreaElement).value,
                })
              }
            />
          </div>

          <div className="mb3">
            <label className="flex items-center">
              <input
                type="checkbox"
                checked={newParam.required || false}
                onChange={(e) =>
                  setNewParam({
                    ...newParam,
                    required: (e.target as HTMLInputElement).checked,
                  })
                }
                className="mr2"
              />
              <span className="fw6">Required</span>
            </label>
          </div>

          <div className="flex items-center gap-2">
            <button
              type="button"
              className="btn btn-primary flex items-center"
              onClick={() => {
                onParameterAdded(newParam);
                setNewParam(emptyParam);
                setIsAddingNew(false);
              }}
              disabled={!newParam.name.trim()}
            >
              <MaterializeIcon name="check" className="mr1"/>
              Save
            </button>
            <button
              type="button"
              className="btn btn-secondary flex items-center"
              onClick={() => {
                setNewParam(emptyParam);
                setIsAddingNew(false);
              }}
            >
              Cancel
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

interface CollapsibleParameterProps {
  param: types.EnvironmentParameter;
  onParamUpdated: (param: types.EnvironmentParameter) => void;
  onParamRemoved: () => void;
  disabled?: boolean;
}

const CollapsibleParameter = (props: CollapsibleParameterProps) => {
  const { param, onParamUpdated, onParamRemoved, disabled } = props;
  const [isExpanded, setIsExpanded] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editedParam, setEditedParam] = useState(param);

  const handleSave = () => {
    onParamUpdated(editedParam);
    setIsEditing(false);
  };

  const handleCancel = () => {
    setEditedParam(param);
    setIsEditing(false);
  };

  return (
    <div className="ba b--black-10 br2 bg-white">
      <div
        className="pa2 flex items-center pointer hover-bg-near-white"
        onClick={() => !isEditing && setIsExpanded(!isExpanded)}
      >
        <MaterializeIcon
          name={isExpanded ? `expand_more` : `chevron_right`}
          className="mr2 gray"
        />
        <div className="flex-1">
          <span className="fw6">{param.name}</span>
          {param.required && (
            <span className="ml2 ba b--black-20 br2 ph1 pv0 gray">
              Required
            </span>
          )}
        </div>
        {!disabled && !isEditing && (
          <div className="flex items-center gap-2" onClick={(e) => e.stopPropagation()}>
            <button
              type="button"
              className="btn btn-link pa1 flex items-center"
              onClick={() => {
                setIsExpanded(true);
                setIsEditing(true);
              }}
            >
              <MaterializeIcon name="edit"/>
            </button>
            <button
              type="button"
              className="btn btn-link pa1 flex items-center red"
              onClick={onParamRemoved}
            >
              <MaterializeIcon name="delete"/>
            </button>
          </div>
        )}
      </div>

      {isExpanded && (
        <div className="pa3 bt b--black-10 bg-near-white">
          {!isEditing ? (
            <div>
              {param.description && (
                <div className="mb2">
                  <label className="db fw6 gray mb1">Description</label>
                  <p className="ma0 lh-copy">{param.description}</p>
                </div>
              )}
              {!param.description && (
                <p className="ma0 gray i">No description provided</p>
              )}
            </div>
          ) : (
            <div>
              <div className="mb2">
                <label className="db fw6 mb1">Parameter Name *</label>
                <input
                  type="text"
                  className="form-control pa2 w-100"
                  value={editedParam.name}
                  onChange={(e) =>
                    setEditedParam({
                      ...editedParam,
                      name: (e.target as HTMLInputElement).value,
                    })
                  }
                />
              </div>

              <div className="mb2">
                <label className="db fw6 mb1">Description</label>
                <textarea
                  className="form-control pa2 w-100"
                  value={editedParam.description}
                  rows={2}
                  onChange={(e) =>
                    setEditedParam({
                      ...editedParam,
                      description: (e.target as HTMLTextAreaElement).value,
                    })
                  }
                />
              </div>

              <div className="mb3">
                <label className="flex items-center">
                  <input
                    type="checkbox"
                    checked={editedParam.required || false}
                    onChange={(e) =>
                      setEditedParam({
                        ...editedParam,
                        required: (e.target as HTMLInputElement).checked,
                      })
                    }
                    className="mr2"
                  />
                  <span className="fw6">Required</span>
                </label>
              </div>

              <div className="flex items-center gap-2">
                <button
                  type="button"
                  className="btn btn-primary flex items-center"
                  onClick={handleSave}
                  disabled={!editedParam.name.trim()}
                >
                  <MaterializeIcon name="check" className="mr1"/>
                  Save
                </button>
                <button
                  type="button"
                  className="btn btn-secondary flex items-center"
                  onClick={handleCancel}
                >
                  Cancel
                </button>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
};
