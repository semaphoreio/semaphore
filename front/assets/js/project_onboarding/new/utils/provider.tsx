import { IntegrationType } from '../types/provider';
import { h, Fragment } from 'preact';

export const getProviderName = (type: IntegrationType | string): string => {
  switch (type) {
    case IntegrationType.GithubApp:
    case IntegrationType.GithubOauthToken:
      return `GitHub`;
    case IntegrationType.BitBucket:
      return `Bitbucket`;
    case IntegrationType.Gitlab:
      return `GitLab`;
    default:
      return type;
  }
};

export const getProviderNameWithBadge = (type: IntegrationType | string) => {
  if (type === IntegrationType.GithubOauthToken) {
    return (
      <Fragment>
        GitHub
        <span className="f6 normal ml2 ph1 br2 bg-yellow white pointer">
          Personal Token
        </span>
        {` `}
      </Fragment>
    );
  }
  return <Fragment>{getProviderName(type)}</Fragment>;
};

export const getProviderIcon = (type: IntegrationType | string): string | null => {
  switch (type) {
    case IntegrationType.GithubApp:
    case IntegrationType.GithubOauthToken:
      return `images/icn-github.svg`;
    case IntegrationType.BitBucket:
      return `images/icn-bitbucket.svg`;
    case IntegrationType.Gitlab:
      return `images/icn-gitlab.svg`;
    default:
      return null;
  }
};

export const getProviderDescription = (type: IntegrationType | string, status: string | null): string => {
  if (status !== `connected` && status !== null) {
    return `You will be taken to set up a connection with ${getProviderName(type)}.`;
  }

  switch (type) {
    case IntegrationType.GithubApp:
    case IntegrationType.GithubOauthToken:
      return `Automate builds for your GitHub repositories.`;
    case IntegrationType.BitBucket:
      return `Seamless integration with Bitbucket Cloud and Server.`;
    default:
      return `Run builds on changes in your ${getProviderName(type)} repository.`;
  }
};
