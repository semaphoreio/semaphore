import { createContext } from "preact";

export interface State {
  createOrganizationURL: string;
}

export const Context = createContext<{ config: State, }>({
  config: {
    createOrganizationURL: ``,
  },
});
