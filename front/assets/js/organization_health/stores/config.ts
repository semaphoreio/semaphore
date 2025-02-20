import { createContext } from "preact";
import { DateRangeItem } from "../types";

export interface State {
  baseUrl: string;
  organizationHealthUrl: string;
  dateRange: DateRangeItem[];
}

export const Context = createContext<State>({
  baseUrl: ``,
  organizationHealthUrl: ``,
  dateRange: [],
});
