export type Action =
  | { type: `SET_STATE`, branches: Branch[], }
  | { type: `SET_ACTIVE_BRANCH`, branch: Branch, }
  ;
interface Branch {
  value: string;
  label: string;
  url: string;
}

export interface State {
  branches: Branch[];
  activeBranch?: Branch;
}

export function Reducer(state: State, action: Action): State {
  switch (action.type) {
    case `SET_STATE`:
      if (action.branches.length > 0) {
        return { ...state, branches: action.branches, activeBranch: action.branches[0] };
      } else {
        return { ...state, branches: action.branches };
      }
    case `SET_ACTIVE_BRANCH`:
      return { ...state, activeBranch: action.branch };
    default:
      return state;
  }
}
