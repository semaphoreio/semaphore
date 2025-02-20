import { createContext } from "preact";
import * as types from "../types";

export type Action =
  | { type: `SET_LEARN`, value: types.Onboarding.Learn, }
  | { type: `SELECT_TASK`, value: string, };

export interface State {
  currentTask?: types.Onboarding.Task;
  learn: types.Onboarding.Learn;
}

export const Reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case `SET_LEARN`:
      return { ...state, learn: action.value };

    case `SELECT_TASK`: {
      const task = state.learn.sections
        .flatMap((section) => section.tasks)
        .find((task) => task.id == action.value);

      if (task?.isSelectable()) {
        return { ...state, currentTask: task };
      } else {
        return { ...state, currentTask: undefined };
      }
    }
    default:
      return state;
  }
};

export const EmptyState: State = {
  learn: new types.Onboarding.Learn(),
};

export const Context = createContext<{
  state: State;
  dispatch: (a: Action) => void;
}>({ state: EmptyState, dispatch: () => undefined });
