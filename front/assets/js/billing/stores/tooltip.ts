import { createContext } from "preact";
import type { PlotData } from "../components/charts";

export type Action =
  | { type: `SET_X`, value: number }
  | { type: `SET_Y`, value: number }
  | { type: `SET_HIDDEN`, value: boolean }
  | { type: `SET_FOCUS`, value: boolean }
  | { type: `SET_TOOLTIP_METRICS`, value: PlotData[] }
  | { type: `SET_DETAIL_NAME`, value: string }
  | { type: `SET_TOOLTIP`, x: number, y: number, hidden: boolean, tooltipMetrics: PlotData[], selectedDate: Date };

export interface State {
  x: number;
  y: number;
  hidden: boolean;
  focus: boolean;
  tooltipMetrics: PlotData[];
  detailName?: string;
  detailValue?: number;
  selectedDate?: Date;
}

export const Reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case `SET_X`:
      return { ...state, x: action.value };
    case `SET_Y`:
      return { ...state, y: action.value };
    case `SET_HIDDEN`:
      return { ...state, hidden: action.value };
    case `SET_FOCUS`:
      return { ...state, focus: action.value };
    case `SET_TOOLTIP_METRICS`:
      return { ...state, tooltipMetrics: action.value };
    case `SET_DETAIL_NAME`:
      return { ...state, detailName: action.value };
    case `SET_TOOLTIP`:
      return {
        ...state,
        x: action.x,
        y: action.y,
        hidden: action.hidden,
        tooltipMetrics: action.tooltipMetrics,
        selectedDate: action.selectedDate,
      };
    default:
      return state;
  }
};

export const EmptyState: State = {
  x: 0,
  y: 0,
  hidden: true,
  focus: false,
  tooltipMetrics: [],
};

export const Context = createContext<{ state: State, dispatch: (a: Action) => void }>({ state: EmptyState, dispatch: () => undefined });
