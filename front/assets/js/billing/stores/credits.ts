import { createContext } from "preact";
import * as types from "../types";
import Credits = types.Credits;

export enum Status {
  Empty = `empty`,
  Loading = `loading`,
  Loaded = `loaded`,
  Error = `error`,
}

export type Action =
  | { type: `SET_AVAILABLE`, available: Credits.Available[] }
  | { type: `SET_BALANCE`, balance: Credits.Balance[] }
  | { type: `SET_STATUS`, value: Status }
  | { type: `SET_STATUS_MESSAGE`, value: string };

export interface State {
  url: string;
  status: Status;
  statusMessage: string;
  available: Credits.Available[];
  balance: Credits.Balance[];
}

export const Reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case `SET_AVAILABLE`:
      return { ...state, available: action.available };
    case `SET_BALANCE`:
      return { ...state, balance: action.balance };
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
  available: [],
  balance: [],
};

export const Context = createContext<{ state: State, dispatch: (a: Action) => void }>({
  state: EmptyState,
  dispatch: () => undefined,
});
