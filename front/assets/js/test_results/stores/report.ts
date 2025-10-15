import { createContext } from "preact";
import { Report } from "../types/report";

export type Action =
  | { type: `SET_ITEMS`, items: Report[] }
  | { type: `SELECT_ITEM`, item: Report }
  ;

export interface State {
  items: Report[];
  selectedItem?: Report;
  isEmpty: boolean;
}

export const Reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case `SET_ITEMS`:
      return { ...state, items: action.items, isEmpty: action.items.length === 0 };
    case `SELECT_ITEM`:
      return { ...state, selectedItem: action.item };
    default:
      return state;
  }
};

export const EmptyState: State = {
  items: [] as Report[],
  isEmpty: false
};

export const Context = createContext<{ state: State, dispatch: (a: Action) => void }>({ state: EmptyState, dispatch: () => undefined });
