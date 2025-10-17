export type Action =
    | { type: `SET_CD_BRANCH_NAME`, value: string }
    | { type: `SET_CD_PIPELINE_FILE_NAME`, value: string }
    | { type: `SET_CI_BRANCH_NAME`, value: string }
    | { type: `SET_CI_PIPELINE_FILE_NAME`, value: string }
    | { type: `SET_STATE`, state: State }
    ;


export interface State {
  ciBranchName: string;
  ciPipelineFileName: string;

  cdBranchName: string;
  cdPipelineFileName: string;
}

export function Reducer(state: State, action: Action): State {
  switch (action.type) {
    case `SET_CD_BRANCH_NAME`:
      return { ...state, cdBranchName: action.value };
    case `SET_CD_PIPELINE_FILE_NAME`:
      return { ...state, cdPipelineFileName: action.value };
    case `SET_CI_BRANCH_NAME`:
      return { ...state, ciBranchName: action.value };
    case `SET_CI_PIPELINE_FILE_NAME`:
      return { ...state, ciPipelineFileName: action.value };
    case `SET_STATE`:
      return { ...state, ...action.state };
    default:
      return state;
  }
}
export const EmptyState: State = {
  ciBranchName: ``,
  ciPipelineFileName: ``,
  cdBranchName: ``,
  cdPipelineFileName: ``,
};

