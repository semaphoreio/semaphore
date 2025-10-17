import { createContext } from "preact";
import type * as tests from "../types/tests";
import moment from "moment";

export type Action =
    | { type: `SET_QUERY`, value: string }
    | { type: `SET_FILTERS`, value: tests.Filter[] }
    | { type: `SET_CURRENT_FILTER`, value: tests.Filter }
    | { type: `DELETE_FILTER`, value: string }
    | { type: `CREATE_FILTER`, value: tests.Filter }
    | { type: `UPDATE_FILTER`, value: tests.Filter }
    ;

export interface State {
  currentFilter?: tests.Filter;
  query?: string;
  filters: tests.Filter[];
}

const monthFilter = (month: Date): string => {
  const date = moment(month);
  const startOfMonth = date.clone().startOf(`month`).format(`YYYY-MM-DD`);
  const endOfMonth = date.clone().endOf(`month`).add(1, `day`).format(`YYYY-MM-DD`);

  return `@date.from:${startOfMonth} @date.to:${endOfMonth}`;
};

const builtInFilters: tests.Filter[] = [
  {
    id: `1`,
    name: `Current month`,
    value: monthFilter(moment().toDate()),
    readOnly: true,
  },
  {
    id: `2`,
    name: `Previous month`,
    value: monthFilter(moment().subtract(1, `month`).toDate()),
    readOnly: true,
  },
];

export const Reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case `SET_FILTERS`:
      return {
        ...state,
        filters: [...builtInFilters, ...action.value],
      };
    case `SET_QUERY`:
      return {
        ...state,
        query: action.value,
      };
    case `SET_CURRENT_FILTER`:
      return {
        ...state,
        currentFilter: action.value,
        query: action.value.value,
      };
    case `DELETE_FILTER`:
      return {
        ...state,
        filters: state.filters.filter((filter) => filter.id !== action.value),
        currentFilter: null,
        query: ``,
      };

    case `CREATE_FILTER`:
      return {
        ...state,
        filters: [...state.filters, action.value],
        currentFilter: action.value,
        query: action.value.value,
      };

    case `UPDATE_FILTER`:
      return {
        ...state,
        filters: state.filters.map((filter) => {
          if(filter.id === action.value.id) {
            return action.value;
          }
          return filter;
        }),
        currentFilter: action.value,
        query: action.value.value,
      };
  }
};

export const EmptyState: State = {
  filters: builtInFilters,
  query: ``,
};

export const Context = createContext<{ state: State, dispatch: (a: Action) => void }>({ state: EmptyState, dispatch: () => undefined });
