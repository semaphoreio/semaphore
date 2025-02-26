import { Fragment } from "preact";
import { NavLink, useParams } from "react-router-dom";
import { useContext, useEffect, useState } from "preact/hooks";
import * as stores from "../stores";
import * as types from "../types";
import { GithubIntegration } from "./integration_page/github";
import { GitlabIntegration } from "./integration_page/gitlab";
import { BitbucketIntegration } from "./integration_page/bitbucket";

export const IntegrationPage = () => {
  const config = useContext(stores.Config.Context);
  const { type } = useParams();

  const [integration, setIntegration] = useState(null);

  useEffect(() => {
    // First check existing integrations
    const existingIntegration = config.integrations.find(i => i.type === type);
    if (existingIntegration) {
      setIntegration(existingIntegration);
      return;
    }

    // If not found and it's gitlab or bitbucket, check newIntegrations
    if (type === types.Integration.IntegrationType.Gitlab ||
        type === types.Integration.IntegrationType.BitBucket) {
      const newIntegration = config.newIntegrations.find(i => i.type === type);
      if (newIntegration) {
        setIntegration(newIntegration);
        return;
      }
    }
  }, [type]);

  if (!integration) {
    return (
      <Fragment>
        <NavLink className="gray link f6 mb2 dib" to="/">
          ← Back to Integration
        </NavLink>
        <h2 className="f3 f2-m mb0">Not Found</h2>
      </Fragment>
    );
  }

  const csrfToken = document
    .querySelector(`meta[name="csrf-token"]`)
    .getAttribute(`content`);

  switch (integration.type) {
    case types.Integration.IntegrationType.GithubApp:
      return <GithubIntegration integration={integration} csrfToken={csrfToken}/>;
    case types.Integration.IntegrationType.Gitlab:
      return <GitlabIntegration integration={integration} csrfToken={csrfToken} orgUsername={config.orgUsername}/>;
    case types.Integration.IntegrationType.BitBucket:
      return <BitbucketIntegration integration={integration} csrfToken={csrfToken} orgUsername={config.orgUsername}/>;
    default:
      return (
        <Fragment>
          <NavLink className="gray link f6 mb2 dib" to="/">
            ← Back to Integration
          </NavLink>
          <h2 className="f3 f2-m mb0">Unsupported Integration Type</h2>
        </Fragment>
      );
  }
};
