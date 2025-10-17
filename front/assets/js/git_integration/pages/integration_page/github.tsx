import { Fragment } from "preact";
import { NavLink } from "react-router-dom";
import { useState } from "preact/hooks";
import * as components from "../../components";
import type * as types from "../../types";

interface Props {
  integration: types.Integration.GithubIntegration;
  csrfToken: string;
}

export const GithubIntegration = ({ integration, csrfToken }: Props) => {
  const [deleteDisabled, setDeleteDisabled] = useState(true);
  const deleteInputChange = (e: any) => {
    if (e.target.value === integration.appName) {
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
      <h2 data-testid="integration-title" className="f3 f2-m mb0">{integration.appName}</h2>
      <p className="measure">
        GitHub Cloud integration through installed GitHub App.
      </p>

      <div className="pv3 bt b--lighter-gray">
        <div className="mb1">
          <label className="b mr1">GitHub App Connection</label>
          {integration.connectionStatus && (
            <components.ConnectionStatus status={integration.connectionStatus}/>
          )}
        </div>
        <p className="mb3">
          Check your GitHub App settings against the parameters listed here
          to ensure a working connection.
        </p>

        <a
          href={integration.htmlUrl}
          target="_blank"
          rel="noreferrer"
        >
          Configure GitHub App Settings ↗
        </a>

        <div className="mv3 br3 shadow-3 bg-white pa3 bb b--black-075">
          <div className="flex items-center justify-between mb2 pb3 bb bw1 b--black-075 br3 br--top">
            <div className="flex items-center">
              <span className="material-symbols-outlined mr2">
                list_alt_check
              </span>
              <span className="b f5">Configuration parameters</span>
            </div>
          </div>

          <EditFields integration={integration}/>
          <CopyFields integration={integration}/>
        </div>

        <components.PrivateKeyBox
          value={integration.privateKeySignature}
          editUrl={integration.updateUrl}
        />
      </div>

      {/* delete integration  */}
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
            Enter app name to confirm:
          </label>
          <div className="flex items-center">
            <form
              className="flex items-center w-100"
              method="post"
              action={integration.deleteUrl}
            >
              <input
                type="hidden"
                name="_csrf_token"
                value={csrfToken}
              />
              <input
                type="hidden"
                name="type"
                value="github_app"
              />
              <input
                type="text"
                className="form-control w-100"
                placeholder="Enter app name..."
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
    </div>
  );
};

const EditFields = ({ integration }: { integration: types.Integration.GithubIntegration }) => {
  return (
    <Fragment>
      <components.EditField
        title="App ID"
        type={integration.type}
        editUrl={integration.updateUrl}
        editKey="app_id"
        value={integration.appId}
      />

      <components.EditField
        title="App Name"
        type={integration.type}
        editUrl={integration.updateUrl}
        editKey="name"
        value={integration.name}
      />

      <components.EditField
        title="App slug"
        type={integration.type}
        editUrl={integration.updateUrl}
        editKey="slug"
        value={integration.appName}
      />
      <components.EditField
        title="Public link"
        type={integration.type}
        editUrl={integration.updateUrl}
        editKey="html_url"
        value={integration.htmlUrl}
      />

      <components.EditField
        title="Client ID"
        type={integration.type}
        editUrl={integration.updateUrl}
        editKey="client_id"
        value={integration.clientId}
        isPrivate
      />
      <components.EditField
        title="Client Secret"
        type={integration.type}
        editUrl={integration.updateUrl}
        editKey="client_secret"
        isPrivate
      />
      <components.EditField
        title="Webhook secret"
        type={integration.type}
        editUrl={integration.updateUrl}
        editKey="webhook_secret"
        isPrivate
      />
    </Fragment>
  );
};

const CopyFields = ({ integration }: { integration: types.Integration.GithubIntegration }) => {
  const manifest = integration.manifest as {
    callback_urls: string;
    setup_url: string;
    url: string;
    webhook_url: string;
    permissions: string;
  };

  const callbackUrls = manifest.callback_urls.split(`,`).map(url => url.trim());

  return (
    <Fragment>
      <components.CopyField title="Home page URL" url={manifest.url}/>
      {callbackUrls.map((url, index) => (
        <components.CopyField
          key={index}
          title="Callback URL"
          url={url}
        />
      ))}
      <components.CopyField title="Webhook URL" url={manifest.webhook_url}/>
      <components.CopyField title="Setup URL" url={manifest.setup_url}/>
      <components.PermissionsField permissions={manifest.permissions}/>
    </Fragment>
  );
};
