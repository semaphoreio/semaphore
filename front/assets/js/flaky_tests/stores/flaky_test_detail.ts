import { createContext } from "preact";
import type { Tests } from "../types";

export type Action =
  | { type: `SET_TEST`, value: Tests.FlakyDetail }
  ;

export interface State {
  test: Tests.FlakyDetail;
}

export const Reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case `SET_TEST`:
      return { ...state, test: action.value };
    default:
      return state;
  }
};

export const EmptyState: State = {
  test: null,
};

export const Context = createContext<{ state: State, dispatch: (a: Action) => void }>({ state: EmptyState, dispatch: () => undefined });
