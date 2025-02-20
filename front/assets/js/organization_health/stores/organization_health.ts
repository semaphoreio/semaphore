import { createContext } from "preact";
import { BranchType, BuildStatus, ProjectHealth, Status } from "../types";


export type Action =
    | { type: `SET_ORG_HEALTH`, orgHealth: ProjectHealth[], }
    | { type: `SET_STATUS`, status: Status, }
    | { type: `SET_BRANCH_TYPE`, branchType: BranchType, }
    | { type: `SET_BUILD_STATUS`, buildStatus: BuildStatus, }
    | { type: `SET_PROJECT_NAME`, value: string, }
    | { type: `SELECT_DATES`, value: number, };

export interface State {
  url: string;
  orgHealth: ProjectHealth[];
  status: Status;
  selectedDateIndex: number;
  filters: { branchType: BranchType, buildStatus: BuildStatus, projectName: string, };
}

export const Reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case `SET_ORG_HEALTH`:
      return {
        ...state,
        orgHealth: action.orgHealth,
      };
    case `SET_STATUS`:
      return {
        ...state,
        status: action.status,
      };
    case `SELECT_DATES`:
      return {
        ...state,
        selectedDateIndex: action.value,
      };
    case `SET_BRANCH_TYPE`:
      return {
        ...state,
        filters: {
          ...state.filters,
          branchType: action.branchType,
        }
      };
    case `SET_BUILD_STATUS`:
      return {
        ...state,
        filters: {
          ...state.filters,
          buildStatus: action.buildStatus,
        }
      };
    case `SET_PROJECT_NAME`:
      return {
        ...state,
        filters: {
          ...state.filters,
          projectName: action.value,
        }
      };
    default:
      return state;
  }
};

export const EmptyState: State = {
  url: ``,
  orgHealth: [],
  status: Status.Empty,
  selectedDateIndex: 0,
  filters: {
    branchType: BranchType.All,
    buildStatus: BuildStatus.All,
    projectName: ``,
  }
};

export const Context = createContext<{ state: State, dispatch: (a: Action) => void, }>({ state: EmptyState, dispatch: () => undefined });