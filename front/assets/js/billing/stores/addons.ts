import * as types from "../types";
import Addons = types.Addons;

export enum Status {
  Empty = `empty`,
  Loading = `loading`,
  Loaded = `loaded`,
  Error = `error`,
}

export type Action =
  | { type: `SET_GROUPS`; groups: Addons.AddonGroup[] }
  | { type: `SET_STATUS`; value: Status }
  | { type: `SET_UPDATING`; value: string | null }
  ;

export interface State {
  status: Status;
  groups: Addons.AddonGroup[];
  updating: string | null;
}

export const Reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case `SET_GROUPS`:
      return { ...state, groups: action.groups };
    case `SET_STATUS`:
      return { ...state, status: action.value };
    case `SET_UPDATING`:
      return { ...state, updating: action.value };
    default:
      return state;
  }
};

export const EmptyState: State = {
  status: Status.Empty,
  groups: [],
  updating: null,
};
