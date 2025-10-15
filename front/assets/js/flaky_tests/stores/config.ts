import { createContext } from "preact";

export interface State {
  baseURL: string;
  flakyURL: string;
  flakyDetailsURL: string;
  flakyDisruptionOccurencesURL: string;
  disruptionHistoryURL: string;
  flakyHistoryURL: string;
  filtersURL: string;
  removeFilterURL: string;
  createFilterURL: string;
  updateFilterURL: string;
  webhookSettingsURL: string;
}

export const Context = createContext<State>({
  baseURL: ``,
  flakyURL: ``,
  flakyDetailsURL: ``,
  flakyDisruptionOccurencesURL: ``,
  disruptionHistoryURL: ``,
  flakyHistoryURL: ``,
  filtersURL: ``,
  removeFilterURL: ``,
  createFilterURL: ``,
  updateFilterURL: ``,
  webhookSettingsURL: ``,
});
