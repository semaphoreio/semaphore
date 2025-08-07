import { Fragment, render } from "preact";
import { useState, useContext, useEffect, useCallback } from "preact/hooks";
import { Modal, Box } from "js/toolbox";
import { AppConfig, ConfigContext } from "./config";
import { ServiceAccount, AppState } from "./types";
import { ServiceAccountsAPI } from "./utils/api";
import { ServiceAccountsList } from "./components/ServiceAccountsList";
import { CreateServiceAccount } from "./components/CreateServiceAccount";
import { EditServiceAccount } from "./components/EditServiceAccount";
import { TokenDisplay } from "./components/TokenDisplay";

export default function ({
  dom,
  config: jsonConfig,
}: {
  dom: HTMLElement;
  config: any;
}) {
  render(
    <ConfigContext.Provider value={AppConfig.fromJSON(jsonConfig)}>
      <App/>
    </ConfigContext.Provider>,
    dom
  );
}

const App = () => {
  const config = useContext(ConfigContext);
  const api = new ServiceAccountsAPI(config);

  const [state, setState] = useState<AppState>({
    serviceAccounts: [],
    loading: true,
    error: null,
    selectedServiceAccount: null,
    newToken: null,
    page: 1,
    totalPages: 0,
  });

  const [createModalOpen, setCreateModalOpen] = useState(false);
  const [editModalOpen, setEditModalOpen] = useState(false);
  const [deleteModalOpen, setDeleteModalOpen] = useState(false);
  const [regenerateModalOpen, setRegenerateModalOpen] = useState(false);

  const loadServiceAccounts = useCallback(async (page?: number) => {
    setState(prev => ({ ...prev, loading: true, error: null }));

    const response = await api.list(page);

    if (response.error) {
      setState(prev => ({
        ...prev,
        loading: false,
        error: response.error || `Failed to load service accounts`
      }));
    } else if (response.data) {
      setState(prev => ({
        ...prev,
        loading: false,
        page: page || 1,
        serviceAccounts: page > 1
          ? [...prev.serviceAccounts, ...response.data.items]
          : response.data.items,
        totalPages: response.data.totalPages || null,
      }));
    }
  }, []);

  useEffect(() => {
    void loadServiceAccounts();
  }, []);

  const handleEdit = (account: ServiceAccount) => {
    setState(prev => ({ ...prev, selectedServiceAccount: account }));
    setEditModalOpen(true);
  };

  const handleDelete = (account: ServiceAccount) => {
    setState(prev => ({ ...prev, selectedServiceAccount: account }));
    setDeleteModalOpen(true);
  };

  const confirmDelete = async () => {
    if (!state.selectedServiceAccount) return;

    setState(prev => ({ ...prev, loading: true }));
    const response = await api.delete(state.selectedServiceAccount.id);

    if (response.error) {
      setState(prev => ({ ...prev, loading: false, error: response.error || `Failed to delete` }));
    } else {
      await loadServiceAccounts();
      setDeleteModalOpen(false);
      setState(prev => ({ ...prev, selectedServiceAccount: null }));
    }
  };

  const handleRegenerateToken = (account: ServiceAccount) => {
    setState(prev => ({ ...prev, selectedServiceAccount: account }));
    setRegenerateModalOpen(true);
  };

  const confirmRegenerateToken = async () => {
    if (!state.selectedServiceAccount) return;

    setState(prev => ({ ...prev, loading: true }));
    const response = await api.regenerateToken(state.selectedServiceAccount.id);

    if (response.error) {
      setState(prev => ({ ...prev, loading: false, error: response.error || `Failed to regenerate token` }));
    } else if (response.data) {
      setState(prev => ({ ...prev, loading: false, newToken: response.data.api_token }));
      setRegenerateModalOpen(false);
    }
  };

  const handleTokenDisplayClose = () => {
    setState(prev => ({ ...prev, newToken: null, selectedServiceAccount: null }));
    void loadServiceAccounts();
  };

  const hasMorePages = state.totalPages && state.page < state.totalPages;

  const handleLoadMore = () => {
    if (hasMorePages) {
      void loadServiceAccounts(state.page + 1);
    }
  };

  return (
    <Fragment>
      {state.error && (
        <div className="bg-washed-red ba b--red br2 pa3 mb3">
          <p className="f6 mb0 red">{state.error}</p>
        </div>
      )}

      <ServiceAccountsList
        serviceAccounts={state.serviceAccounts}
        loading={state.loading}
        onEdit={handleEdit}
        onDelete={handleDelete}
        onRegenerateToken={handleRegenerateToken}
        onLoadMore={handleLoadMore}
        hasMore={hasMorePages}
        onCreateNew={() => setCreateModalOpen(true)}
      />

      <CreateServiceAccount
        isOpen={createModalOpen}
        onClose={() => setCreateModalOpen(false)}
        onCreated={() => void loadServiceAccounts()}
      />

      <EditServiceAccount
        serviceAccount={state.selectedServiceAccount}
        isOpen={editModalOpen}
        onClose={() => {
          setEditModalOpen(false);
          setState(prev => ({ ...prev, selectedServiceAccount: null }));
        }}
        onUpdated={() => void loadServiceAccounts()}
      />

      <Modal
        isOpen={deleteModalOpen}
        close={() => setDeleteModalOpen(false)}
        title="Delete Service Account"
      >
        <div className="pa3">
          <p className="f5 mb3">
            Are you sure you want to delete the service account{` `}
            <strong>{state.selectedServiceAccount?.name}</strong>?
          </p>
          <p className="f6 gray mb3">
            This will immediately revoke API access. This action cannot be undone.
          </p>
        </div>
        <div className="flex justify-end items-center pa3 bt b--black-10">
          <button
            className="btn btn-secondary mr3"
            onClick={() => setDeleteModalOpen(false)}
          >
            Cancel
          </button>
          <button
            className="btn btn-danger"
            onClick={() => void confirmDelete()}
            disabled={state.loading}
          >
            {state.loading ? `Deleting...` : `Delete Service Account`}
          </button>
        </div>
      </Modal>

      <Modal
        isOpen={regenerateModalOpen}
        close={() => setRegenerateModalOpen(false)}
        title="Regenerate API Token"
      >
        <div className="pa3">
          <p className="f5 mb3">
            Are you sure you want to regenerate the API token for{` `}
            <strong>{state.selectedServiceAccount?.name}</strong>?
          </p>
          <Box type="warning" className="mb3">
            The current token will be immediately invalidated.
            <br/>
            Any systems using the old token will lose access.
          </Box>
        </div>
        <div className="flex justify-end items-center pa3 bt b--black-10">
          <button
            className="btn btn-secondary mr3"
            onClick={() => setRegenerateModalOpen(false)}
          >
            Cancel
          </button>
          <button
            className="btn btn-primary"
            onClick={() => void confirmRegenerateToken()}
            disabled={state.loading}
          >
            {state.loading ? `Regenerating...` : `Regenerate Token`}
          </button>
        </div>
      </Modal>

      {state.newToken && (
        <Modal
          isOpen={true}
          close={handleTokenDisplayClose}
          title="New API Token"
        >
          <TokenDisplay token={state.newToken} onClose={handleTokenDisplayClose}/>
        </Modal>
      )}
    </Fragment>
  );
};
