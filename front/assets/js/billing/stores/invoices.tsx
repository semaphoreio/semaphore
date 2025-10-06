import { createContext } from "preact";
import * as types from "../types";
import Spendings = types.Spendings;

export enum Status {
  Empty = `empty`,
  Loading = `loading`,
  Loaded = `loaded`,
  Error = `error`,
}

export type Action =
  | { type: `SET_INVOICES`, invoices: Spendings.Invoice[] }
  | { type: `SET_STATUS`, value: Status }
  | { type: `SET_STATUS_MESSAGE`, value: string };

export interface State {
  url: string;
  status: Status;
  statusMessage: string;
  invoices: Spendings.Invoice[];
}

export const Reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case `SET_INVOICES`:
      return { ...state, invoices: action.invoices };
    case `SET_STATUS`:
      return { ...state, status: action.value };
    case `SET_STATUS_MESSAGE`:
      return { ...state, statusMessage: action.value };
    default:
      return state;
  }
};

export const EmptyState: State = {
  url: ``,
  status: Status.Empty,
  statusMessage: ``,
  invoices: [],
};

export const Context = createContext<{ state: State, dispatch: (a: Action) => void }>({
  state: EmptyState,
  dispatch: () => undefined,
});
