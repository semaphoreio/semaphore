import { createContext } from "preact";
import { UrlState } from "../util";

export type Action =
  | { type: `SET_ACTIVE_REPORT`, reportId: string }
  | { type: `SET_ACTIVE_SUITE`, suiteId: string }
  | { type: `SET_ACTIVE_TEST`, testId: string }
  ;

export interface State {
  activeReportId: string;
  activeSuiteId: string;
  activeTestId: string;
}

export const Reducer = (state: State, action: Action): State => {
  switch (action.type) {
    case `SET_ACTIVE_REPORT`:
      if(action.reportId != ``) {
        UrlState.set(`report_id`, action.reportId);
        UrlState.unset(`suite_id`);
        UrlState.unset(`test_id`);
      } else {
        UrlState.unset(`report_id`);
        UrlState.unset(`suite_id`);
        UrlState.unset(`test_id`);
      }
      return { ...state, activeReportId: action.reportId, activeSuiteId: ``, activeTestId: `` };
    case `SET_ACTIVE_SUITE`:
      if(action.suiteId != ``) {
        UrlState.set(`suite_id`, action.suiteId);
        UrlState.unset(`test_id`);
      } else {
        UrlState.unset(`suite_id`);
        UrlState.unset(`test_id`);
      }
      return { ...state, activeSuiteId: action.suiteId, activeTestId: `` };
    case `SET_ACTIVE_TEST`:
      if(action.testId != ``) {
        UrlState.set(`test_id`, action.testId);
      } else {
        UrlState.unset(`test_id`);
      }
      return { ...state, activeTestId: action.testId };
  }
};

export const EmptyState: State = {
  activeReportId: ``,
  activeSuiteId: ``,
  activeTestId: ``,
};

export const Context = createContext<{ state: State, dispatch: (a: Action) => void }>({ state: EmptyState, dispatch: () => undefined });
