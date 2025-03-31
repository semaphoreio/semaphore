export class Provider {
  type: IntegrationType;
  status?: ProviderStatus;
  scopeUpdate?: ScopeUpdate;
}

export class ScopeUpdate {
  url: string;
  method: string;
}

export enum ProviderStatus {
  Connected = `connected`,
  WithError = `with_error`,
  NotConnected = `not_connected`,
}

export enum IntegrationType {
  GithubApp = `github_app`,
  GithubOauthToken = `github_oauth_token`,
  BitBucket = `bitbucket`,
  Gitlab = `gitlab`,
  Git = `git`,
}
