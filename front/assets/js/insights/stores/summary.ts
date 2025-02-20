import { createContext } from "preact";
import * as types from "../types";

export type Action =
  | { type: `SET_SUMMARY`, summary: types.Summary.Project, };


export interface State {
  projectSummary?: types.Summary.Project;
}

export const Reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case `SET_SUMMARY`:
      return { ...state, projectSummary: action.summary };

    default:
      return state;
  }
};

export const EmptyState: State = {};

export const Context = createContext<State>(EmptyState);
