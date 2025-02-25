import { Fragment } from "preact";
import * as types from "../types";
import * as stores from "../stores";
import * as toolbox from "js/toolbox";
import { getProviderName, getProviderIcon } from '../utils/provider';

export interface ScopeContentProps {
  selectedProvider: types.Provider.Provider;
  user: stores.Create.Config.State[`user`];
  scopeUrls: stores.Create.Config.State[`scopeUrls`];
  userProfileUrl?: stores.Create.Config.State[`userProfileUrl`];
  csrfToken?: string;
}

export const ScopeContent = ({ selectedProvider, user, scopeUrls, userProfileUrl, csrfToken }: ScopeContentProps) => {
  if (!user || !scopeUrls) return null;

  const providerScopeUrls = scopeUrls[selectedProvider.type];
  if (!providerScopeUrls) return null;

  const needsScope = (
    (selectedProvider.type === `github_app` && user.github_scope === `NONE`) ||
    (selectedProvider.type === `github_oauth_token` && [`NONE`, `EMAIL`].includes(user.github_scope)) ||
    (selectedProvider.type === `bitbucket` && [`NONE`, `EMAIL`].includes(user.bitbucket_scope)) ||
    (selectedProvider.type === `gitlab` && [`NONE`, `EMAIL`].includes(user.gitlab_scope))
  );

  if (!needsScope) return null;

  return (
    <Fragment>
      <div className="bg-washed-yellow pa3 mv3 mr2 shadow-1 br2">
        <p className="mb0 f4">
          <toolbox.Asset path={getProviderIcon(selectedProvider.type)} className="mr1"/>
          Your {getProviderName(selectedProvider.type)} Account is not connected
        </p>
        <p className="mb3 pt2 bt b--black-10">
            Connect your {getProviderName(selectedProvider.type)} account to enable workflow YAML file commits. View your Semaphore profile settings{` `}
          <a href={userProfileUrl || `/account/profile`}>here</a>.
        </p>
        {providerScopeUrls.map((scope, index) => (
          <a
            key={index}
            href={scope.url}
            className="btn btn-secondary inline-flex items-center mr3"
            data-tippy-content={scope.description}
            data-csrf={csrfToken}
            data-method="post"
            data-to={scope.url}
            rel="nofollow"
          >
            <toolbox.Asset path={getProviderIcon(selectedProvider.type)}/>
            <span>{scope.title}</span>
          </a>
        ))}
      </div>
    </Fragment>
  );
};
