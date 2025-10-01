import { useState } from "preact/hooks";
import { MaterializeIcon } from "js/toolbox";
import * as types from "../types";

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
  const [isAddingNew, setIsAddingNew] = useState(false);

  return (
    <div>
      {contexts.length === 0 && !isAddingNew && (
        <div className="mb3 ba b--black-10 br2 pa2 bg-near-white mb2 flex flex-column gap-1">
          <p className="ma0 gray lh-copy tc">
            No context variables defined yet.
          </p>
        </div>
      )}

      {contexts.length > 0 && (
        <div className="flex flex-column gap-2 mb3">
          {contexts.map((context, index) => (
            <CollapsibleContext
              key={index}
              context={context}
              onContextUpdated={(updatedContext) =>
                onContextUpdated(context.name, updatedContext)
              }
              onContextRemoved={() => onContextRemoved(context)}
              disabled={disabled}
            />
          ))}
        </div>
      )}

      {!disabled && !isAddingNew && (
        <button
          type="button"
          className="btn btn-secondary flex items-center"
          onClick={() => setIsAddingNew(true)}
        >
          <MaterializeIcon name="add" className="mr1"/>
          Add Context Variable
        </button>
      )}

      {!disabled && isAddingNew && (
        <div className="ba b--black-10 br2 pa3 bg-white mb2">
          <div className="mb2">
            <label className="db fw6 mb1">Variable Name *</label>
            <input
              type="text"
              className="form-control pa2 w-100"
              placeholder="e.g., REGION"
              value={newContext.name}
              onChange={(e) =>
                setNewContext({
                  ...newContext,
                  name: (e.target as HTMLInputElement).value,
                })
              }
            />
          </div>

          <div className="mb3">
            <label className="db fw6 mb1">Description</label>
            <textarea
              className="form-control pa2 w-100"
              placeholder="What is this context variable used for?"
              value={newContext.description}
              rows={2}
              onChange={(e) =>
                setNewContext({
                  ...newContext,
                  description: (e.target as HTMLTextAreaElement).value,
                })
              }
            />
          </div>

          <div className="flex items-center gap-2">
            <button
              type="button"
              className="btn btn-primary flex items-center"
              onClick={() => {
                onContextAdded(newContext);
                setNewContext(emptyContext);
                setIsAddingNew(false);
              }}
              disabled={!newContext.name.trim()}
            >
              <MaterializeIcon name="check" className="mr1"/>
              Save
            </button>
            <button
              type="button"
              className="btn btn-secondary flex items-center"
              onClick={() => {
                setNewContext(emptyContext);
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

interface CollapsibleContextProps {
  context: types.EnvironmentContext;
  onContextUpdated: (context: types.EnvironmentContext) => void;
  onContextRemoved: () => void;
  disabled?: boolean;
}

const CollapsibleContext = (props: CollapsibleContextProps) => {
  const { context, onContextUpdated, onContextRemoved, disabled } = props;
  const [isExpanded, setIsExpanded] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editedContext, setEditedContext] = useState(context);

  const handleSave = () => {
    onContextUpdated(editedContext);
    setIsEditing(false);
  };

  const handleCancel = () => {
    setEditedContext(context);
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
          <span className="fw6">{context.name}</span>
        </div>
        {!disabled && !isEditing && (
          <div
            className="flex items-center gap-2"
            onClick={(e) => e.stopPropagation()}
          >
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
              onClick={onContextRemoved}
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
              {context.description && (
                <div className="mb2">
                  <label className="db fw6 gray mb1">Description</label>
                  <p className="ma0 lh-copy">{context.description}</p>
                </div>
              )}
              {!context.description && (
                <p className="ma0 gray i">No description provided</p>
              )}
            </div>
          ) : (
            <div>
              <div className="mb2">
                <label className="db fw6 mb1">Variable Name *</label>
                <input
                  type="text"
                  className="form-control pa2 w-100"
                  value={editedContext.name}
                  onChange={(e) =>
                    setEditedContext({
                      ...editedContext,
                      name: (e.target as HTMLInputElement).value,
                    })
                  }
                />
              </div>

              <div className="mb3">
                <label className="db fw6 mb1">Description</label>
                <textarea
                  className="form-control pa2 w-100"
                  value={editedContext.description}
                  rows={2}
                  onChange={(e) =>
                    setEditedContext({
                      ...editedContext,
                      description: (e.target as HTMLTextAreaElement).value,
                    })
                  }
                />
              </div>

              <div className="flex items-center gap-2">
                <button
                  type="button"
                  className="btn btn-primary flex items-center"
                  onClick={handleSave}
                  disabled={!editedContext.name.trim()}
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
