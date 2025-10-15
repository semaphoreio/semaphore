import { createContext } from "preact";
import { Integration } from "../types";

export interface State {
  baseUrl: string;
  orgId: string;
  orgUsername: string;
  domain: string;
  csrfTokenCookieKey: string;
  integrations?: Integration.Integration[];
  newIntegrations?: Integration.NewIntegration[];
  redirectToAfterSetup?: string;
}

export const Context = createContext<State>({
  baseUrl: ``,
  orgId: ``,
  orgUsername: ``,
  domain: ``,
  csrfTokenCookieKey: `githubAppInstallStatusToken`,
});
