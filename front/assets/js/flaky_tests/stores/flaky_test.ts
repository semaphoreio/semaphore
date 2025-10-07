import { HistoryItem, FlakyTestItem } from "../types/flaky_test_item";
import { Status } from "../types";
import { createContext } from "preact";
import { FlakyTestsFilter } from "../types/flaky_tests_filter";
import { StateUpdater } from "preact/hooks";

export type Action =
    | { type: `SET_FLAKY_URL`, value: string }
    | { type: `SET_FLAKY`, value: FlakyTestItem[] }
    | { type: `SET_STATUS`, status: Status }
    | { type: `SET_DISRUPTION_HISTORY`, value: HistoryItem[] }
    | { type: `SET_DISRUPTION_CHART_STATUS`, status: Status }
    | { type: `SET_FLAKY_HISTORY`, value: HistoryItem[] }
    | { type: `SET_FLAKY_CHART_STATUS`, status: Status }
    | { type: `SET_FLAKY_COUNT`, value: number }
    | { type: `SET_SORT_ORDER`, value: string[] }
    | { type: `SET_SEARCH_FILTER`, value: string }
    | { type: `SET_FLAKY_FILTER_LIST`, value: FlakyTestsFilter[] }
    | { type: `SET_FILTER_STATUS`, status: Status }
    | { type: `DELETE_FILTER`, value: FlakyTestsFilter }
    | { type: `CREATE_FILTER`, value: FlakyTestsFilter }
    | { type: `UPDATE_FILTER`, value: FlakyTestsFilter[] }
    | { type: `LOAD_PAGE`, page: number }
    | { type: `SET_TOTAL_PAGES`, value: number }
    ;

export interface State {
  flakyUrl: string;
  flakyCount: number;
  flakyTests: FlakyTestItem[];
  status: Status;
  disruptionHistory: HistoryItem[];
  disruptionHistoryStatus: Status;
  flakyHistory: HistoryItem[];
  flakyHistoryStatus: Status;

  sortOrder: string[];

  searchFilter: string;

  flakyTestsFilters: FlakyTestsFilter[];
  filtersStatus: Status;

  page: number;
  totalPages: number;
}


export const Reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case `SET_FLAKY`:
      return {
        ...state,
        flakyTests: action.value,
      };
    case `SET_STATUS`:
      return {
        ...state,
        status: action.status,
      };
    case `SET_DISRUPTION_HISTORY`:
      return {
        ...state,
        disruptionHistory: action.value,
      };
    case `SET_DISRUPTION_CHART_STATUS`:
      return {
        ...state,
        disruptionHistoryStatus: action.status,
      };

    case `SET_FLAKY_HISTORY`:
      return {
        ...state,
        flakyHistory: action.value,
      };
    case `SET_FLAKY_CHART_STATUS`:
      return {
        ...state,
        flakyHistoryStatus: action.status,
      };
    case `SET_FLAKY_COUNT`:
      return {
        ...state,
        flakyCount: action.value,
      };
    case `SET_FLAKY_URL`:
      return {
        ...state,
        flakyUrl: action.value,
      };
    case `SET_SORT_ORDER`:
      return {
        ...state,
        sortOrder: action.value,
      };
    case `SET_SEARCH_FILTER`:
      // There's no change in filter, skip update.
      if(state.searchFilter === action.value)
        return state;
      return {
        ...state,
        searchFilter: action.value,
      };
    case `SET_FLAKY_FILTER_LIST`:
      return {
        ...state,
        flakyTestsFilters: action.value,
      };
    case `DELETE_FILTER`:
      return {
        ...state,
        flakyTestsFilters: state.flakyTestsFilters.filter((filter) => filter.id !== action.value.id),
      };

    case `CREATE_FILTER`:
      return {
        ...state,
        flakyTestsFilters: [...state.flakyTestsFilters, action.value],
      };

    case `UPDATE_FILTER`:
      return {
        ...state,
        flakyTestsFilters: action.value,
      };
    case `LOAD_PAGE`:
      return {
        ...state,
        page: action.page,
      };
    case `SET_TOTAL_PAGES`:
      return {
        ...state,
        totalPages: action.value,
      };
    case `SET_FILTER_STATUS`: {
      return {
        ...state,
        filtersStatus: action.status,
      };
    }

  }
};

export const EmptyState: State = {
  flakyUrl: ``,
  flakyCount: 0,
  flakyTests: [],
  status: Status.Empty,
  disruptionHistory: [],
  disruptionHistoryStatus: Status.Empty,
  flakyHistory: [],
  flakyHistoryStatus: Status.Empty,

  sortOrder: [`total_disruptions_count`, `desc`],

  searchFilter: ``,
  flakyTestsFilters: [],
  filtersStatus: Status.Empty,

  page: 1,
  totalPages: 1,
};

export const Context = createContext<{ state: State, dispatch: (a: Action) => void, query: string, setQuery: StateUpdater<string> }>({ state: EmptyState, dispatch: () => undefined, query: ``, setQuery: () => undefined });
