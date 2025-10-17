import { createContext } from "preact";
import type { Provider } from "../../types";

export interface State {
  baseUrl: string;
  duplicateCheckUrl: string;
  createProjectUrl: string;
  createProjectStatusUrl: string;
  domain: string;
  repositoriesUrl: string;
  providers?: Provider.Provider[];
  primaryProvider?: Provider.Provider;
  userProfileUrl?: string;
  setupIntegrationUrl: string;
  csrfToken: string;
  skipOnboardingUrl?: string;
  projectUrl?: string;
  scopeUrls?: {
    github_oauth_token?: Array<{
      url: string;
      title: string;
      description: string;
    }>;
    github_app?: Array<{
      url: string;
      title: string;
      description: string;
    }>;
    bitbucket?: Array<{
      url: string;
      title: string;
      description: string;
    }>;
    gitlab?: Array<{
      url: string;
      title: string;
      description: string;
    }>;
  };
  githubAppInstallationUrl?: string;
  user?: {
    id: string;
    github_uid: string;
    github_scope: string;
    github_login: string;
    email: string;
    bitbucket_uid: string;
    bitbucket_scope: string;
    bitbucket_login: string;
    gitlab_scope: string;
  };
}

export const Context = createContext<State>({
  baseUrl: ``,
  domain: ``,
  providers: [],
  setupIntegrationUrl: `settings/git_integrations/`,
  repositoriesUrl: `/repositories`,
  userProfileUrl: `/account/profile`,
  csrfToken: ``,
  duplicateCheckUrl: ``,
  createProjectUrl: ``,
  createProjectStatusUrl: ``,
});
