import { useState, useContext, useEffect } from "preact/hooks";
import { Modal } from "js/toolbox";
import { ConfigContext } from "../config";
import { ServiceAccountsAPI } from "../utils/api";
import { ServiceAccount } from "../types";
import * as toolbox from "js/toolbox";

interface EditServiceAccountProps {
  serviceAccount: ServiceAccount | null;
  isOpen: boolean;
  onClose: () => void;
  onUpdated: () => void;
}

export const EditServiceAccount = ({
  serviceAccount,
  isOpen,
  onClose,
  onUpdated
}: EditServiceAccountProps) => {
  const config = useContext(ConfigContext);
  const api = new ServiceAccountsAPI(config);

  const [name, setName] = useState(``);
  const [description, setDescription] = useState(``);
  const [selectedRoleId, setSelectedRoleId] = useState(``);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(``);

  useEffect(() => {
    if (serviceAccount) {
      setName(serviceAccount.name);
      setDescription(serviceAccount.description);
      setSelectedRoleId(serviceAccount.roles.find((role) => role.source == `manual`)?.id || ``);
    }
  }, [serviceAccount]);

  const handleSubmit = async (e: Event) => {
    e.preventDefault();
    if (!serviceAccount) return;

    setError(null);
    setLoading(true);

    const response = await api.update(serviceAccount.id, name, description, selectedRoleId);

    if (response.error) {
      setError(response.error);
      setLoading(false);
    } else {
      onUpdated();
      handleClose();
    }
  };

  const handleClose = () => {
    setError(null);
    setLoading(false);
    onClose();
  };

  const hasChanges = serviceAccount && (
    name !== serviceAccount.name ||
    description !== serviceAccount.description ||
    selectedRoleId !== serviceAccount.roles.find((role) => role.source == `manual`)?.id
  );

  const canSubmit = name.trim().length > 0 && !loading && hasChanges;

  if (!serviceAccount) return null;

  return (
    <Modal isOpen={isOpen} close={handleClose} title="Edit Service Account">
      <form onSubmit={(e) => void handleSubmit(e)}>
        <div className="pa3">
          <div className="mb3">
            <label className="db mb2 f6 b">Name *</label>
            <input
              type="text"
              className="form-control w-100"
              value={name}
              onInput={(e) => setName(e.currentTarget.value)}
              placeholder="e.g., CI/CD Pipeline"
              disabled={loading}
              autoFocus
            />
          </div>

          <div className="mb3">
            <label className="db mb2 f6 b">Description</label>
            <textarea
              className="form-control w-100"
              value={description}
              onInput={(e) => setDescription(e.currentTarget.value)}
              placeholder="Optional description of what this service account is used for"
              rows={3}
              disabled={loading}
            />
          </div>


          <div className="mb3">
            <label className="db mb2 f6 b">Role *</label>
            <select
              className="form-control w-100"
              value={selectedRoleId}
              onChange={(e) => setSelectedRoleId(e.currentTarget.value)}
              disabled={loading}
            >
              <option value="">Select a role...</option>
              {config.roles.map((role) => (
                <option key={role.id} value={role.id}>
                  {role.name} - {role.description}
                </option>
              ))}
            </select>
          </div>

          {error && (
            <div className="bg-washed-red ba b--red br2 pa2 mb3">
              <p className="f6 mb0 red">{error}</p>
            </div>
          )}
        </div>

        <div className="flex justify-end items-center pa3 bt b--black-10">
          <button
            type="button"
            className="btn btn-secondary mr3"
            onClick={handleClose}
            disabled={loading}
          >
            Cancel
          </button>
          <button
            type="submit"
            className="btn btn-primary"
            disabled={!canSubmit}
          >
            {loading ? (
              <span className="flex items-center">
                <toolbox.Asset path="images/spinner.svg" className="mr2"/>
                Saving...
              </span>
            ) : (
              `Save Changes`
            )}
          </button>
        </div>
      </form>
    </Modal>
  );
};
