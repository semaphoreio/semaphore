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
  const [ownershipModalOpen, setOwnershipModalOpen] = useState(false);
  const [releaseModalOpen, setReleaseModalOpen] = useState(false);

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
      // The account may have lost its owner over this, so the rows are read again.
      await loadServiceAccounts();
    }
  };

  // The owner lends the account their access to repositories, so a token asked for by
  // anybody else leaves it without one. An owner who is no longer a member lends nothing,
  // so there is nothing to say about one.
  const takesOwnershipAway = (account?: ServiceAccount) =>
    config.showOwnership &&
    !!account?.owner &&
    account.owner_active &&
    account.owner.id !== config.userId;

  const handleTakeOwnership = (account: ServiceAccount) => {
    setState(prev => ({ ...prev, selectedServiceAccount: account }));
    setOwnershipModalOpen(true);
  };

  const confirmTakeOwnership = async () => {
    if (!state.selectedServiceAccount) return;

    setState(prev => ({ ...prev, loading: true }));
    const response = await api.takeOwnership(state.selectedServiceAccount.id);

    if (response.error) {
      setState(prev => ({ ...prev, loading: false, error: response.error || `Failed to take ownership` }));
      setOwnershipModalOpen(false);
    } else {
      await loadServiceAccounts();
      setOwnershipModalOpen(false);
      setState(prev => ({ ...prev, selectedServiceAccount: null }));
    }
  };

  const handleReleaseOwnership = (account: ServiceAccount) => {
    setState(prev => ({ ...prev, selectedServiceAccount: account }));
    setReleaseModalOpen(true);
  };

  const confirmReleaseOwnership = async () => {
    if (!state.selectedServiceAccount) return;

    setState(prev => ({ ...prev, loading: true }));
    const response = await api.releaseOwnership(state.selectedServiceAccount.id);

    if (response.error) {
      setState(prev => ({ ...prev, loading: false, error: response.error || `Failed to give up ownership` }));
      setReleaseModalOpen(false);
    } else {
      await loadServiceAccounts();
      setReleaseModalOpen(false);
      setState(prev => ({ ...prev, selectedServiceAccount: null }));
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
        onTakeOwnership={handleTakeOwnership}
        onReleaseOwnership={handleReleaseOwnership}
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
          {takesOwnershipAway(state.selectedServiceAccount) && (
            <Box type="warning" className="mb3">
              {state.selectedServiceAccount.owner.name} owns this account
              {config.ownershipEnforced ? `, and it uses their access to repositories` : ``}.
              Regenerating the token leaves it without an owner until a member takes it on.
            </Box>
          )}
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

      <Modal
        isOpen={ownershipModalOpen}
        close={() => setOwnershipModalOpen(false)}
        title="Take Ownership"
      >
        <div className="pa3">
          <p className="f5 mb3">
            Take ownership of{` `}
            <strong>{state.selectedServiceAccount?.name}</strong>?
          </p>
          <Box type="warning" className="mb3">
            {config.ownershipEnforced
              ? `Projects this account adds will use your access to the repository.`
              : `You will be recorded as the member this account acts for.`}
            <br/>
            Anyone who manages service accounts can take ownership from you later.
          </Box>
        </div>
        <div className="flex justify-end items-center pa3 bt b--black-10">
          <button
            className="btn btn-secondary mr3"
            onClick={() => setOwnershipModalOpen(false)}
          >
            Cancel
          </button>
          <button
            className="btn btn-primary"
            onClick={() => void confirmTakeOwnership()}
            disabled={state.loading}
          >
            {state.loading ? `Taking ownership...` : `Take Ownership`}
          </button>
        </div>
      </Modal>

      <Modal
        isOpen={releaseModalOpen}
        close={() => setReleaseModalOpen(false)}
        title="Give Up Ownership"
      >
        <div className="pa3">
          <p className="f5 mb3">
            Give up ownership of{` `}
            <strong>{state.selectedServiceAccount?.name}</strong>?
          </p>
          <Box type="warning" className="mb3">
            {config.ownershipEnforced
              ? `The account will not be able to add projects until someone takes it on.`
              : `The account will have no owner until someone takes it on.`}
            <br/>
            Projects it already has keep working.
          </Box>
        </div>
        <div className="flex justify-end items-center pa3 bt b--black-10">
          <button
            className="btn btn-secondary mr3"
            onClick={() => setReleaseModalOpen(false)}
          >
            Cancel
          </button>
          <button
            className="btn btn-primary"
            onClick={() => void confirmReleaseOwnership()}
            disabled={state.loading}
          >
            {state.loading ? `Giving up ownership...` : `Give Up Ownership`}
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
