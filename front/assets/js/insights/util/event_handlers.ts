import type { Action as MDPAction } from "../stores/metric_date_range";
import type { Action as BAction } from "../stores/branches";
import type { State as BState } from "../stores/branches";
import { useSearchParams } from "react-router-dom";

export const handleMetricDatePickerChanged = (dispatch: (action: MDPAction) => void) => {
  return (e: Event) => {
    const target = e.target as HTMLInputElement;
    dispatch({ type: `SELECT_METRIC_DATE_RANGE`, value: target.value });
  };
};

export const handleBranchChanged = (state: BState, dispatch: (action: BAction) => void) => {
  const [searchParams, setSearchParams] = useSearchParams();

  return (e: Event) => {
    const target = e.target as HTMLInputElement;
    const branch = state.branches.find(b => b.value === target.value);
    if (branch && branch !== state.activeBranch) {
      dispatch({ type: `SET_ACTIVE_BRANCH`, branch });
      searchParams.set(`branch`, branch.value);
      setSearchParams(searchParams, { replace: true });
    }
  };
};