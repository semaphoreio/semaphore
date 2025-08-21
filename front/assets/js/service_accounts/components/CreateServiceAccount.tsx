import { useState, useContext } from "preact/hooks";
import { Modal } from "js/toolbox";
import { ConfigContext } from "../config";
import { ServiceAccountsAPI } from "../utils/api";
import { TokenDisplay } from "./TokenDisplay";
import * as toolbox from "js/toolbox";

interface CreateServiceAccountProps {
  isOpen: boolean;
  onClose: () => void;
  onCreated: () => void;
}

export const CreateServiceAccount = ({ isOpen, onClose, onCreated }: CreateServiceAccountProps) => {
  const config = useContext(ConfigContext);
  const api = new ServiceAccountsAPI(config);

  const [name, setName] = useState(``);
  const [description, setDescription] = useState(``);
  const [selectedRoleId, setSelectedRoleId] = useState(``);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(``);
  const [token, setToken] = useState(``);

  const handleSubmit = async (e: Event) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    const response = await api.create(name, description, selectedRoleId);

    if (response.error) {
      setError(response.error);
      setLoading(false);
    } else if (response.data) {
      setToken(response.data.api_token);
      setLoading(false);
    }
  };

  const handleClose = () => {
    if (token) {
      onCreated();
    }
    setName(``);
    setDescription(``);
    setSelectedRoleId(``);
    setError(``);
    setToken(``);
    onClose();
  };

  const canSubmit = name.trim().length > 0 && selectedRoleId.length > 0 && !loading;

  return (
    <Modal isOpen={isOpen} close={handleClose} title="Create Service Account">
      {!token ? (
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

          <div className="flex justify-end items-center pa2 bt b--black-10">
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
                  Creating...
                </span>
              ) : (
                `Create Service Account`
              )}
            </button>
          </div>
        </form>
      ) : (
        <TokenDisplay token={token} onClose={handleClose}/>
      )}
    </Modal>
  );
};
