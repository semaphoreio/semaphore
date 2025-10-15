import { createContext } from "preact";
import { Spendings } from "../types";

export type Action =
  | { type: `SET_RESULT`, value: Spendings.Spending[] }
  | { type: `SELECT_SPENDING`, value: string }
  | { type: `SET_CURRENT_SPENDING`, value: Spendings.Spending }
  ;

export interface State {
  spendings: Spendings.Spending[];
  selectedSpendingId: string;
  selectedSpending?: Spendings.Spending;
  currentSpending?: Spendings.Spending;
}

export const Reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case `SET_RESULT`:
      return { ...state, spendings: action.value };
    case `SELECT_SPENDING`:
      return {
        ...state,
        selectedSpendingId: action.value,
        selectedSpending: state.spendings.find(s => s.id === action.value),
      };
    case `SET_CURRENT_SPENDING`:
      return {
        ...state,
        currentSpending: action.value,
      };
    default:
      return state;
  }
};

export const EmptyState: State = {
  spendings: [],
  selectedSpendingId: ``,
};

export const Context = createContext<{ state: State, dispatch: (a: Action) => void }>({ state: EmptyState, dispatch: () => undefined });
