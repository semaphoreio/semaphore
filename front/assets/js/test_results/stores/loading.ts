export type Action =
  | { type: `LOADING`, }
  | { type: `ADD_ERROR`, error: string, }
  | { type: `RESET`, }
  | { type: `LOADED`, }
  ;


export interface State {
  loading: boolean;
  errors: string[];
}

export const Reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case `RESET`:
      return { loading: false, errors: [] };
    case `LOADING`:
      return { ...state, loading: true, errors: [] };
    case `LOADED`:
      return { ...state, loading: false };
    case `ADD_ERROR`:
      return { ...state, loading: false, errors: [...state.errors, action.error] };
    default:
      return state;
  }
};

export type Dispatcher = (action: Action) => void;

export const EmptyState: State = {
  loading: false,
  errors: [],
};
