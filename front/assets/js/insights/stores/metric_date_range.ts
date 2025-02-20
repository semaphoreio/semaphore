import { createContext } from "preact";
import { MetricDateRange } from "../types/metric_date_range";

export type Action =
    | { type: `SET_METRIC_DATE_RANGES`, value: MetricDateRange[], }
    | { type: `SELECT_METRIC_DATE_RANGE`, value: string, }
    ;

export const Reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case `SET_METRIC_DATE_RANGES`:
      return { ...state, dateRanges: action.value,
        selectedMetricDateRangeLabel: action.value[0].label,
        selectedMetricDateRange: action.value[0]
      };
    case `SELECT_METRIC_DATE_RANGE`:
      return {
        ...state,
        selectedMetricDateRangeLabel: action.value,
        selectedMetricDateRange: state.dateRanges.find(s => s.label === action.value),
      };
    default:
      return state;
  }
};


export interface State {
  selectedMetricDateRangeLabel: string;
  selectedMetricDateRange?: MetricDateRange;
  dateRanges: MetricDateRange[];
}


export const EmptyState: State = {
  dateRanges: [],
  selectedMetricDateRangeLabel: ``,
};

export const Context = createContext<{ state: State, dispatch: (a: Action) => void, }>({ state: EmptyState, dispatch: () => undefined });