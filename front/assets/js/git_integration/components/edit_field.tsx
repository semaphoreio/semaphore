import { Fragment, h } from "preact";
import { useState } from "preact/hooks";
import * as types from "../types";
import { LockIcon } from "./lock_icon";

interface EditFieldProps {
  title: string;
  value?: string;
  type: types.Integration.IntegrationType;
  editKey: string;
  editUrl: string;
  isPrivate?: boolean;
}

const privateFieldPlaceholder = `••••••••••`;

export const EditField = ({
  title,
  value,
  editKey,
  editUrl,
  isPrivate
}: EditFieldProps) => {
  const [isEditing, setIsEditing] = useState(false);
  const [inputValue, setInputValue] = useState(value);
  const [error, setError] = useState<string | null>(null); // To hold any error message

  const csrfToken = document
    .querySelector(`meta[name="csrf-token"]`)
    .getAttribute(`content`);

  const handleEditClick = () => {
    setIsEditing(true);
  };

  const handleSave = () => {
    fetch(editUrl, {
      method: `POST`,
      headers: {
        "Content-Type": `application/json`,
        "X-CSRF-Token": csrfToken || ``,
      },
      body: JSON.stringify({ [editKey]: inputValue }),
    })
      .then((response) => {
        if (!response.ok) {
          throw new Error(`Failed to save.`);
        }
        setIsEditing(false);
      })
      .catch((err) => {
        setInputValue(value);
        setError(
          err instanceof Error ? err.message : `Failed to save. Please try again.`
        );
      });
  };

  const handleCancel = () => {
    setInputValue(value); // Reset to original value
    setIsEditing(false);
  };

  const inputValueToDisplay = isPrivate ? privateFieldPlaceholder : inputValue;

  return (
    <Fragment>
      <div className="flex items-center justify-between">
        <div className="flex items-center" style="gap: 0.5rem;">
          <p className="f5 mv2">{title}</p>
          {isPrivate && <LockIcon/>}
        </div>
        {/* {editElement} */}
        <a
          onClick={handleEditClick}
          className="material-symbols-outlined f5 b btn pointer pa1 btn-secondary ml3"
          data-tippy-content="Update this parameter"
        >
          edit
        </a>
      </div>
      {isEditing ? (
        <div className="flex items-center">
          <input
            type="text"
            className="form-control w-100"
            placeholder={`Enter ${title}...`}
            value={inputValue}
            onInput={(e) => setInputValue(e.currentTarget.value)}
          />
          <button
            className="btn btn-primary ml2"
            type="button"
            onClick={handleSave}
          >
            Save
          </button>
          <button
            className="btn btn-secondary ml2"
            type="button"
            onClick={handleCancel}
          >
            Cancel
          </button>
        </div>
      ) : (
        inputValueToDisplay && (
          <pre className="f6 bg-washed-yellow mb3 ph3 pv2 ba b--black-075 br3 overflow-auto">
            {inputValueToDisplay}
          </pre>
        )
      )}
      {/* Display error message if any */}
      {error && <p className="error-message">{error}</p>}
      {` `}
    </Fragment>
  );
};
