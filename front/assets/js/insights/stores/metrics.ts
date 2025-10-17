export type Action<T> =
  | { type: `SET_STATE`, state: T }
  ;

export type State<T> = T;

export function Reducer<T>(state: State<T>, action: Action<T>): State<T> {
  switch (action.type) {
    case `SET_STATE`:
      return action.state;
    default:
      return state;
  }
}
