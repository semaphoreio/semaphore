import { useContext } from "preact/hooks";
import { ServiceAccount } from "../types";
import { ConfigContext } from "../config";
import * as toolbox from "js/toolbox";

interface ServiceAccountsListProps {
  serviceAccounts: ServiceAccount[];
  loading: boolean;
  onEdit: (account: ServiceAccount) => void;
  onDelete: (account: ServiceAccount) => void;
  onRegenerateToken: (account: ServiceAccount) => void;
  onLoadMore?: () => void;
  hasMore?: boolean;
  onCreateNew: () => void;
}


export const ServiceAccountsList = ({
  serviceAccounts,
  loading,
  onEdit,
  onDelete,
  onRegenerateToken,
  onLoadMore,
  hasMore,
  onCreateNew
}: ServiceAccountsListProps) => {
  const config = useContext(ConfigContext);

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString(`en-US`, {
      year: `numeric`,
      month: `short`,
      day: `numeric`
    });
  };

  if (loading && serviceAccounts.length === 0) {
    return (
      <div className="bb b--black-075 w-100-l mt4 br3 shadow-3 bg-white">
        <div className="flex items-center justify-between pa3 bb bw1 b--black-075 br3 br--top">
          <div>
            <div className="flex items-center">
              <span className="material-symbols-outlined pr2">key</span>
              <div className="b">Service Accounts</div>
            </div>
          </div>
          {config.permissions.canManage && (
            <button
              className="btn btn-primary flex items-center"
              onClick={onCreateNew}
            >
              <span className="material-symbols-outlined mr2">add</span>
              Create Service Account
            </button>
          )}
        </div>
        <div className="tc pv5">
          <toolbox.Asset path="images/spinner.svg"/>
        </div>
      </div>
    );
  }

  return (
    <div className="bb b--black-075 w-100-l mt4 br3 shadow-3 bg-white">
      <div className="flex items-center justify-between pa3 bb bw1 b--black-075 br3 br--top">
        <div>
          <div className="flex items-center">
            <span className="material-symbols-outlined pr2">key</span>
            <div className="b">Service Accounts</div>
          </div>
        </div>
        {config.permissions.canManage && (
          <button
            className="btn btn-primary flex items-center"
            onClick={onCreateNew}
          >
            <span className="material-symbols-outlined mr2">add</span>
            Create Service Account
          </button>
        )}
      </div>

      {serviceAccounts.length === 0 ? (
        <div className="tc pv5">
          <toolbox.Asset path="images/ill-girl-showing-continue.svg" className="mb3"/>
          <h3 className="f4 mb2">No service accounts yet</h3>
          <p className="f6 gray mb0">
            Create your first service account to get started with API access.
          </p>
        </div>
      ) : (
        <div id="service-accounts">
          {serviceAccounts.map((account, idx) => (
            <div key={account.id} className={`bg-white shadow-1 ph3 pv2 ${idx == serviceAccounts.length - 1 ? `br2 br--bottom` : ``}`}>
              <div className="flex items-center justify-between" style={{ minHeight: `45px` }}>
                <div className="flex items-center">
                  <span className="material-symbols-outlined mr2 f4 gray">key</span>
                  <div>
                    <div className="flex items-center">
                      <span className="b black">{account.name}</span>
                      {account.deactivated ? (
                        <span className="ml2 f7 red bg-washed-red ph2 pv1 br2">Deactivated</span>
                      ) : (
                        <span className="ml2 f7 green bg-washed-green ph2 pv1 br2">Active</span>
                      )}
                    </div>
                    <div className="f7 gray mt1">
                      {account.description || `No description`} • Created {formatDate(account.created_at)}
                    </div>
                  </div>
                </div>

                {config.permissions.canManage && (
                  <div className="flex-shrink-0 pl2">
                    <div className="button-group">
                      <button
                        className="flex items-center btn btn-sm btn-secondary"
                        onClick={() => onEdit(account)}
                        title="Edit"
                      >
                        <span className="material-symbols-outlined mr1">edit</span>
                        <span>Edit</span>
                      </button>
                      <button
                        className="flex items-center btn btn-sm btn-secondary"
                        onClick={() => onRegenerateToken(account)}
                        title="Regenerate Token"
                      >
                        <span className="material-symbols-outlined mr1">refresh</span>
                        <span>Refresh</span>
                      </button>
                      <button
                        className="flex items-center btn btn-sm btn-danger"
                        onClick={() => onDelete(account)}
                        title="Delete"
                      >
                        ×
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {hasMore && (
        <div className="tc pa4">
          <button
            className="btn btn-secondary"
            onClick={onLoadMore}
            disabled={loading}
          >
            {loading ? (
              <span className="flex items-center">
                <toolbox.Asset path="images/spinner.svg" className="w1 h1 mr2"/>
                Loading...
              </span>
            ) : (
              `Load More`
            )}
          </button>
        </div>
      )}
    </div>
  );
};
