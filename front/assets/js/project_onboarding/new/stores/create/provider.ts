import { createContext } from "preact";
import { useReducer } from "preact/hooks";
import { Provider } from "../../types";

export interface State {
  selectedProvider: Provider.Provider;
}

type ProviderAction = 
  | { type: `SET_PROVIDER`, payload: Provider.Provider };

const defaultState: State = {
  selectedProvider: null as unknown as Provider.Provider
};

const providerReducer = (state: State, action: ProviderAction): State => {
  switch (action.type) {
    case `SET_PROVIDER`:
      return {
        ...state,
        selectedProvider: action.payload
      };
    default:
      return state;
  }
};

export function useProviderStore(initialState: State = defaultState) {
  const [state, dispatch] = useReducer(providerReducer, initialState);

  const setProvider = (provider: Provider.Provider) => {
    dispatch({ type: `SET_PROVIDER`, payload: provider });
  };

  return {
    state,
    setProvider,
  };
}

export interface ProviderContextType {
  state: State;
  setProvider: (provider: Provider.Provider) => void;
}

export const Context = createContext<ProviderContextType>({
  state: defaultState,
  setProvider: () => { /* no-op */ },
});
