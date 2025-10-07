import { createContext } from "preact";
import * as Stateful from "../util/stateful";

export type Action =
  | { type: `SET_QUERY`, query: string }
  | { type: `SET_SORT`, sort: SortOrder }
  | { type: `TRIM_REPORT_NAME` }
  | { type: `DONT_TRIM_REPORT_NAME` }
  | { type: `WRAP_LINES` }
  | { type: `DONT_WRAP_LINES` }
  | { type: `SET_TOGGLE`, toggle: boolean }
  | { type: `REMOVE_EXCLUDED_TEST_STATE`, state: Stateful.State }
  | { type: `EXCLUDE_TEST_STATE`, state: Stateful.State }
  | { type: `SET_EXCLUDED_TEST_STATE`, states: Stateful.State[] };

export type SortOrder = `failed-first` | `slowest-first` | `alphabetical`;

export interface State {
  query: string;
  sort: SortOrder;
  wrapTestLines: boolean;
  trimReportName: boolean;
  toggleAll: boolean;
  excludedStates: Stateful.State[];
}

export const Reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case `SET_QUERY`:
      return { ...state, query: action.query };
    case `SET_SORT`:
      return { ...state, sort: action.sort };
    case `TRIM_REPORT_NAME`:
      localStorage.setItem(`TR_TRIM_REPORT_NAME`, `true`);
      return { ...state, trimReportName: true };
    case `DONT_TRIM_REPORT_NAME`:
      localStorage.setItem(`TR_TRIM_REPORT_NAME`, `false`);
      return { ...state, trimReportName: false };
    case `WRAP_LINES`:
      localStorage.setItem(`TR_WRAP_LINES`, `true`);
      return { ...state, wrapTestLines: true };
    case `DONT_WRAP_LINES`:
      localStorage.setItem(`TR_WRAP_LINES`, `false`);
      return { ...state, wrapTestLines: false };
    case `SET_TOGGLE`:
      return { ...state, toggleAll: action.toggle };
    case `EXCLUDE_TEST_STATE`:
      return { ...state, excludedStates: [...state.excludedStates, action.state] };
    case `REMOVE_EXCLUDED_TEST_STATE`:
      return { ...state, excludedStates: state.excludedStates.filter((s) => s !== action.state) };
    case `SET_EXCLUDED_TEST_STATE`:
      return { ...state, excludedStates: action.states };
    default:
      return state;
  }
};

export const EmptyState: State = {
  query: ``,
  wrapTestLines: JSON.parse(localStorage.getItem(`TR_WRAP_LINES`) || `true`),
  trimReportName: JSON.parse(localStorage.getItem(`TR_TRIM_REPORT_NAME`) || `false`),
  toggleAll: false,
  sort: `failed-first`,
  excludedStates: [Stateful.State.EMPTY] as Stateful.State[],
};

export const Context = createContext<{ state: State, dispatch: (a: Action) => void }>({
  state: EmptyState,
  dispatch: () => undefined,
});
