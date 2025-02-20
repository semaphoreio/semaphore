import { createContext } from "preact";

export interface State {
  learn: any;
  baseURL: string;
  signalUrl: string;
}

export const Context = createContext<State>({
  learn: null,
  baseURL: ``,
  signalUrl: ``,
});
