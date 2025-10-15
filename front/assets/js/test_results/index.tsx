import type { ComponentChildren } from "preact";
import { render } from "preact";
import { useReducer } from "preact/hooks";
import { ReportStore, FilterStore, NavigationStore, UrlStore } from "./stores";
import { TestResults } from "./components/test_results";
import { UrlState } from "./util";
import { InteractivePipelineTree } from "./util/interactive_pipeline_tree";

interface InitializationProps {
  jsonURL: string;
  encodedEmail: string;
  scope: string;
  pplTreeLoader: any;
  pipelineId: string;
  pipelineName: string;
  pipelineStatus: string;
  pollURL: string;
  workflowSummaryURL: string;
}

export const StateContext = ({ children, url }: { children?: ComponentChildren, url: string }) => {
  const [reportState, reportDispatch] = useReducer(ReportStore.Reducer, ReportStore.EmptyState);
  const [filterState, filterDispatch] = useReducer(FilterStore.Reducer, FilterStore.EmptyState);
  const [navigationState, navigationDispatch] = useReducer(NavigationStore.Reducer, {
    ...NavigationStore.EmptyState,
    activeReportId: UrlState.get(`report_id`, ``),
    activeSuiteId: UrlState.get(`suite_id`, ``),
    activeTestId: UrlState.get(`test_id`, ``),
  });
  const [urlState, urlDispatch] = useReducer(UrlStore.Reducer, { url });

  return (
    <UrlStore.Context.Provider value={{ state: urlState, dispatch: urlDispatch }}>
      <NavigationStore.Context.Provider value={{ state: navigationState, dispatch: navigationDispatch }}>
        <FilterStore.Context.Provider value={{ state: filterState, dispatch: filterDispatch }}>
          <ReportStore.Context.Provider value={{ state: reportState, dispatch: reportDispatch }}>{children}</ReportStore.Context.Provider>
        </FilterStore.Context.Provider>
      </NavigationStore.Context.Provider>
    </UrlStore.Context.Provider>
  );
};

export default function ({
  dom,
  pplTreeLoader,
  pipelineId,
  pollURL,
  workflowSummaryURL,
  encodedEmail,
  jsonURL,
  scope,
  ...init
}: { dom: HTMLElement } & InitializationProps) {
  render(
    <StateContext url={jsonURL}>
      {scope == `pipeline` && (
        <InteractivePipelineTree
          loader={pplTreeLoader}
          pipelineId={pipelineId}
          pollUrl={pollURL}
          workflowSummaryURL={workflowSummaryURL}
          pipelineName={init.pipelineName}
          pipelineStatus={init.pipelineStatus}
        />
      )}
      <TestResults
        className="flex-l no-ligatures"
        scope={scope}
        encodedEmail={encodedEmail}
      />
    </StateContext>,
    dom
  );
}
