import { createContext } from "preact";
import * as types from "../types";
import Seats = types.Seats;

export enum Status {
  Empty = `empty`,
  Loading = `loading`,
  Loaded = `loaded`,
  Error = `error`,
}

export type Action =
  | { type: `SET_SEATS`, seats: Seats.Seat[] }
  | { type: `ORDER_BY`, value: string }
  | { type: `SET_STATUS`, value: Status }
  | { type: `SET_STATUS_MESSAGE`, value: string };

export interface State {
  url: string;
  status: Status;
  statusMessage: string;
  seats: Seats.Seat[];
  orderBy: string;
}

export const Reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case `SET_SEATS`:
      return { ...state, seats: action.seats };
    case `ORDER_BY`:
      return { ...state, orderBy: action.value };
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
  seats: [],
  orderBy: ``,
};

export const Context = createContext<{ state: State, dispatch: (a: Action) => void }>({
  state: EmptyState,
  dispatch: () => undefined,
});
