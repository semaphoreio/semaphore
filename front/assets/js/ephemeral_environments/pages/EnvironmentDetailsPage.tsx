import { useState, useEffect, useCallback } from "preact/hooks";
import { useParams, useNavigate } from "react-router-dom";
import { Fragment } from "preact";
import { Modal, Box } from "js/toolbox";
import { useConfig } from "../contexts/ConfigContext";
import { EnvironmentDetails } from "../types";
import { Loader } from "../utils/elements";
import { EnvironmentDetails as EnvironmentDetailsComponent } from "../components/EnvironmentDetails";

export const EnvironmentDetailsPage = () => {
  const config = useConfig();
  const navigate = useNavigate();
  const { id } = useParams<{ id: string, }>();

  const [environment, setEnvironment] = useState<EnvironmentDetails | null>(
    null
  );
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [deleteModalOpen, setDeleteModalOpen] = useState(false);
  const [deleteConfirmation, setDeleteConfirmation] = useState(``);

  const loadEnvironmentDetails = useCallback(async () => {
    if (!id) return;

    setLoading(true);
    setError(null);

    const response = await config.apiUrls.show.replace({ __ID__: id }).call();

    if (response.error) {
      setError(response.error || `Failed to load environment details`);
    } else if (response.data) {
      setEnvironment(response.data);
    }

    setLoading(false);
  }, [id, config]);

  useEffect(() => {
    void loadEnvironmentDetails();
  }, [id]);

  const handleDeleteClick = () => {
    setDeleteModalOpen(true);
    setDeleteConfirmation(``);
  };

  const handleDelete = async () => {
    if (!id || !environment) return;
    if (deleteConfirmation !== environment.name) return;

    const response = await config.apiUrls.delete.replace({ __ID__: id }).call();

    if (response.error) {
      console.error(`Failed to delete environment:`, response.error);
    } else {
      navigate(`/`);
    }
  };

  const handleProvision = () => {
    // TODO: Implement provisioning logic
    console.warn(`TODO: Provision new instance`);
  };

  const handleDeprovision = (instanceId: string) => {
    // TODO: Implement deprovisioning logic
    console.warn(`TODO: Deprovision instance:`, instanceId);
  };

  if (loading) {
    return <Loader content="Loading environment..."/>;
  }

  if (error || !environment) {
    return <div>Error: {error || `Environment not found`}</div>;
  }

  return (
    <Fragment>
      <EnvironmentDetailsComponent
        environment={environment}
        onDelete={handleDeleteClick}
        onProvision={handleProvision}
        onDeprovision={void handleDeprovision}
        canManage={config.canManage}
      />

      <Modal
        isOpen={deleteModalOpen}
        close={() => setDeleteModalOpen(false)}
        title="Delete Environment"
      >
        <div className="pa4">
          <Box type="warning" className="mb3">
            <p className="ma0">
              This action cannot be undone. All instances of this environment
              will be terminated.
            </p>
          </Box>

          <p className="mb3">
            Type <strong>{environment.name}</strong> to confirm deletion:
          </p>

          <input
            type="text"
            className="input-reset ba b--black-20 pa2 db w-100 mb3"
            value={deleteConfirmation}
            onChange={(e) =>
              setDeleteConfirmation((e.target as HTMLInputElement).value)
            }
            placeholder="Enter environment name"
          />
        </div>

        <div className="pa3 bt b--black-10 flex justify-end">
          <button
            className="btn btn-secondary mr2"
            onClick={() => setDeleteModalOpen(false)}
          >
            Cancel
          </button>
          <button
            className="btn btn-danger"
            onClick={handleDelete}
            disabled={deleteConfirmation !== environment.name}
          >
            Delete Environment
          </button>
        </div>
      </Modal>
    </Fragment>
  );
};
