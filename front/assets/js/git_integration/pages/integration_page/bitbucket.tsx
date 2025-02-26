import { Fragment } from "preact";
import { useContext } from "preact/hooks";
import { NavLink } from "react-router-dom";
import { useState } from "preact/hooks";
import * as components from "../../components";
import * as types from "../../types";
import * as stores from "../../stores";

interface Props {
  integration: types.Integration.BitbucketIntegration;
  csrfToken: string;
  orgUsername: string;
}

export const BitbucketIntegration = ({ integration, csrfToken, orgUsername }: Props) => {
  const [deleteDisabled, setDeleteDisabled] = useState(true);

  const deleteInputChange = (e: any) => {
    if (e.target.value === orgUsername) {
      setDeleteDisabled(false);
    } else {
      setDeleteDisabled(true);
    }
  };

  return (
    <div>
      <NavLink className="gray link f6 mb2 dib" to="/">
        ← Back to Integration
      </NavLink>
      <h2 className="f3 f2-m mb0">{integration.appName}</h2>
      <p className="measure">{integration.description}</p>

      <div className="pv3 bt b--lighter-gray">
        {integration.updateUrl && (
          <div className="mb1">
            <label className="b mr1">Integration Setup</label>
            {integration.connectionStatus && (
              <components.ConnectionStatus status={integration.connectionStatus}/>
            )}
          </div>
        )}
        {!integration.updateUrl && (
          <div className="mb1">
            <label className="b mr1">Integration Setup</label>
            <div className="mt2">
              <p className="mb3">
              Start by creating a OAuth consumer:&nbsp;
                <a
                  href="https://support.atlassian.com/bitbucket-cloud/docs/use-oauth-on-bitbucket-cloud/"
                  target="_blank"
                  rel="noreferrer"
                >
                Use OAuth on Bitbucket Cloud ↗
                </a>
              </p>
            </div>
          </div>
        )}
        <p className="mb3">
          Configure your application with these parameters, then come back here and fill in the credentials below.
        </p>

        <div className="mv3 br3 shadow-3 bg-white pa3 bb b--black-075">
          <div className="flex items-center justify-between mb2 pb3 bb bw1 b--black-075 br3 br--top">
            <div className="flex items-center">
              <span className="material-symbols-outlined mr2">
                list_alt_check
              </span>
              <span className="b f5">Configuration parameters</span>
            </div>
          </div>

          <CopyFields integration={integration}/>
          <EditFields integration={integration}/>

        </div>
      </div>

      {/* delete integration  */}
      {integration.updateUrl && (
        <div className="pv3 bt b--lighter-gray">
          <div className="mb1 flex items-center">
            <label className="b">Remove connection</label>
            <span className="material-symbols-outlined f5 b pointer ml1">
              warning
            </span>
          </div>
          <p className="mb3">
            Warning: Removing this integration will revoke Semaphore&apos;s
            repository access and may stop builds.
          </p>

          <div className="mb3">
            <label htmlFor="name_of_the_organization" className="db mb2">
              Enter organization name to confirm:
            </label>
            <div className="flex items-center">
              <form
                className="flex items-center w-100"
                method="post"
                action={integration.deleteUrl}
              >
                <input type="hidden" name="_csrf_token" value={csrfToken}/>
                <input type="hidden" name="type" value="bitbucket"/>
                <input
                  type="text"
                  className="form-control w-100"
                  placeholder="Enter organization name..."
                  onChange={deleteInputChange}
                />
                <button
                  className="btn btn-danger ml2"
                  disabled={deleteDisabled}
                  type="submit"
                >
                  Delete
                </button>
              </form>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

const EditFields = ({ integration }: { integration: types.Integration.BitbucketIntegration, }) => {
  const [clientId, setClientId] = useState(``);
  const [clientSecret, setClientSecret] = useState(``);
  const config = useContext(stores.Config.Context);
  const csrfToken = document
    .querySelector(`meta[name="csrf-token"]`)
    .getAttribute(`content`);

  if (!integration.updateUrl) {
    return (
      <Fragment>
        <form
          method="post"
          action={integration.connectUrl}
          className="mb3"
        >
          <input type="hidden" name="_csrf_token" value={csrfToken}/>
          <input type="hidden" name="type" value="bitbucket"/>
          <input type="hidden" name="redirect_to" value={config.redirectToAfterSetup}/>

          <div className="mb3">
            <label className="db mb2">Key</label>
            <input
              type="text"
              name="client_id"
              className="form-control w-100"
              value={clientId}
              onChange={(e) => setClientId(e.currentTarget.value)}
              required
            />
          </div>

          <div className="mb3">
            <label className="db mb2">Secret</label>
            <input
              type="password"
              name="client_secret"
              className="form-control w-100"
              value={clientSecret}
              onChange={(e) => setClientSecret(e.currentTarget.value)}
              required
            />
          </div>

          <button type="submit" className="btn btn-primary">
            Connect Integration
          </button>
        </form>
      </Fragment>
    );
  }

  return (
    <Fragment>
      <components.EditField
        title="Key"
        type={integration.type}
        editUrl={integration.updateUrl}
        editKey="client_id"
        isPrivate
      />
      <components.EditField
        title="Secret"
        type={integration.type}
        editUrl={integration.updateUrl}
        editKey="client_secret"
        isPrivate
      />
    </Fragment>
  );
};

const CopyFields = ({ integration }: { integration: types.Integration.BitbucketIntegration, }) => {
  const manifest = integration.manifest as {
    permissions: string;
    redirect_urls: string;
  };

  const redirectUrls = manifest.redirect_urls.split(`,`).map(url => url.trim());

  return (
    <Fragment>
      <components.CopyField
        title="Callback URL"
        url={redirectUrls}
      />
      <components.PermissionsField permissions={manifest.permissions}/>
    </Fragment>
  );
};
