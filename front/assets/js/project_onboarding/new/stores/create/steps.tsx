import { ComponentChildren, createContext } from "preact";
import { useContext, useReducer } from "preact/hooks";

type Id = any;

export interface Step {
  id: Id;
  completed?: boolean;
}

export interface State<T extends Step> {
  steps: T[];
  currentStepId?: Id;
}

export type Action<T extends Step> = [`SET_CURRENT`, Id] | [`SET_STEPS`, T[]];

export function Reducer<T extends Step>(state: State<T>, action: Action<T>): State<T> {
  switch (action[0]) {
    case `SET_CURRENT`: {
      const stepIdx = state.steps.findIndex(
        (predicate) => predicate.id === action[1],
      );

      if (stepIdx === -1) {
        // eslint-disable-next-line no-console
        console.error(`Step "${action[1] as string}" not found`);
        return state;
      }
      // set all steps before the current step as completed
      const steps = state.steps.map((step, idx) => {return { ...step, completed: idx < stepIdx }; });

      return { ...state, steps, currentStepId: state.steps[stepIdx].id };
    }

    case `SET_STEPS`: {
      if( action[1].length === 0) {
        return { steps: action[1] };
      }

      return Reducer({ ...state, steps: action[1] }, [`SET_CURRENT`, action[1][0].id]);
    }
    default:
      return state;
  }
}

export const Context = createContext({});

interface ProviderProps<T extends Step> {
  children?: ComponentChildren;
  state: State<T>;
}

export function Provider<T extends Step>(props: ProviderProps<T>) {
  const [state, dispatch] = useReducer(Reducer, props.state);
  return (
    <Context.Provider value={{ state, dispatch }}>{props.children}</Context.Provider>
  );
}

export function useSteps<T extends Step>() {
  return useContext<{
    state?: State<T>;
    dispatch?: (a: Action<T>) => void;
  }>(Context);
}
