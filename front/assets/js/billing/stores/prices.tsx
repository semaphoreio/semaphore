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
  | { type: `SET_PRICES`, prices: Spendings.DailySpending[] }
  | { type: `SET_STATUS`, value: Status }
  | { type: `SET_STATUS_MESSAGE`, value: string };

export interface State {
  url: string;
  status: Status;
  statusMessage: string;
  prices: Spendings.DailySpending[];
}

export const Reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case `SET_PRICES`:
      return { ...state, prices: action.prices };
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
  prices: [],
};

export const Context = createContext<{ state: State, dispatch: (a: Action) => void }>({
  state: EmptyState,
  dispatch: () => undefined,
});
