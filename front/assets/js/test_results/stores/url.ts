import { createContext } from "preact";

export type Action =
  | { type: `SET_URL`, url: string }
  ;


export interface State {
  url: string;
}

export const Reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case `SET_URL`:
      return { ...state, url: action.url };
    default:
      return state;
  }
};

export type Dispatcher = (action: Action) => void;

export const EmptyState: State = {
  url: ``,
};

interface ContextInterface {
  state: State;
  dispatch: (a: Action) => void;
}

export const Context = createContext<ContextInterface>({
  state: EmptyState,
  dispatch: () => undefined,
});
