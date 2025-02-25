import { createContext } from "preact";
import * as types from "../types";

export type Action =
  | { type: `SET_STATUS`, value: types.RequestStatus, }
  | { type: `SET_PARAM`, name: string, value: string, }
  | { type: `FETCH`, }
  | { type: `CLEAR_PARAMS`, };

export interface State {
  url: URL;
  status: types.RequestStatus;
}

export const Reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case `SET_STATUS`:
      return { ...state, status: action.value };

    case `SET_PARAM`: {
      const url = new URL(state.url);
      url.searchParams.set(action.name, action.value);
      return { ...state, url };
    }

    case `CLEAR_PARAMS`:
      return { ...state, url: new URL(state.url) };

    case `FETCH`:
      return { ...state, status: types.RequestStatus.Fetch };

    default:
      return state;
  }
};

export const EmptyState: State = {
  url: new URL(`/`, location.origin),
  status: types.RequestStatus.Zero,
};

export const Context = createContext<{
  state: State;
  dispatch: (a: Action) => void;
}>({ state: EmptyState, dispatch: () => undefined });
