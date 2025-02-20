import { createContext } from "preact";

export enum Status {
  Empty = `empty`,
  Loading = `loading`,
  Loaded = `loaded`,
  Error = `error`,
}

export type Action =
  | { type: `SET_STATUS`, value: Status, }
  | { type: `SET_LOADING`, }
  | { type: `SET_LOADED`, }
  | { type: `SET_ERROR`, }
  | { type: `ADD_ERROR`, value: string, }
  | { type: `CLEAN`, };

export interface State {
  status: Status;
  errors: string[];
}

export const Reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case `SET_STATUS`:
      return { ...state, status: action.value };
    case `ADD_ERROR`:
      return { ...state, errors: state.errors.concat([action.value]) };
    case `CLEAN`:
      return { ...EmptyState };
    case `SET_LOADING`:
      return { ...state, status: Status.Loading };
    case `SET_LOADED`:
      return { ...state, status: Status.Loaded };
    case `SET_ERROR`:
      return { ...state, status: Status.Error };
    default:
      return state;
  }
};

export const EmptyState: State = {
  status: Status.Empty,
  errors: [],
};

export const Context = createContext<{
  state: State;
  dispatch: (a: Action) => void;
}>({ state: EmptyState, dispatch: () => undefined });
