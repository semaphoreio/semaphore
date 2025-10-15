import type { ComponentChildren } from "preact";
import { Fragment } from "preact";
import { useContext, useEffect, useReducer } from "preact/hooks";
import { ReportStore, LoadingStore, NavigationStore, UrlStore, FilterStore } from "../stores";
import { Report } from "../types/report";
import Icon from "../util/icon";
import { State } from "../util/stateful";
import { NavBar } from "./nav_bar";
import { TestExplorer } from "./test_explorer";
import { ZeroState } from "./zero_state";
import { DecompressGzip } from "../util/gzip";

export interface Props {
  className?: string;
  scope: string;
  encodedEmail: string;
}

export const TestResults = (props: Props) => {
  const [loadingState, loadingDispatch] = useReducer(LoadingStore.Reducer, LoadingStore.EmptyState);
  const reports = useContext(ReportStore.Context);
  const navigation = useContext(NavigationStore.Context);
  const filter = useContext(FilterStore.Context);
  const api = useContext(UrlStore.Context);

  const handleStatus = (response: Response) => {
    if (response.ok) {
      return response
        .blob()
        .then((blob) => {
          // Attempt to decompress, fallback to regular JSON if it fails
          return DecompressGzip(blob).catch(() => blob.text());
        })
        .then((data) => {
          try {
            // Try parsing the data as JSON
            const jsonData = JSON.parse(data as string);
            return Promise.resolve(jsonData);
          } catch (error) {
            throw new Error(`Parsing failed - ${error as string}`);
          }
        });
    }

    switch (response.status) {
      case 404:
        return Promise.resolve({ testResults: [] });
      default:
        throw new Error(`Unexpected response status: ${response.status}`);
    }
  };

  useEffect(() => {
    if (api.state.url != ``) {
      loadingDispatch({ type: `LOADING` });
      fetch(api.state.url)
        .then(handleStatus)
        .then((jsonPayload) => {
          if (jsonPayload.testResults.length == 0) {
            reports.dispatch({ type: `SET_ITEMS`, items: [] });
            navigation.dispatch({ type: `SET_ACTIVE_REPORT`, reportId: `` });
            return;
          }

          const loadedReports = jsonPayload.testResults.map(Report.fromJSON) as Report[];
          loadedReports.sort((a: Report, b: Report) => {
            const failedDiff = b.summary.failed - a.summary.failed;
            if (failedDiff == 0) {
              return a.name.localeCompare(b.name, undefined, {
                numeric: true,
                sensitivity: `base`,
              });
            } else {
              return failedDiff;
            }
          });

          reports.dispatch({ type: `SET_ITEMS`, items: loadedReports });

          if (
            navigation.state.activeReportId === `` ||
            !loadedReports.find((report: any) => report.id === navigation.state.activeReportId)
          ) {
            const activeReport = loadedReports[0];
            navigation.dispatch({ type: `SET_ACTIVE_REPORT`, reportId: activeReport.id });
            const failedSuites = activeReport.suites.filter((suite) => suite.state == State.FAILED);
            if (failedSuites.length > 0) {
              filter.dispatch({ type: `SET_EXCLUDED_TEST_STATE`, states: [State.EMPTY, State.SKIPPED, State.PASSED] });
            }
          }
        })
        .catch((error) => {
          loadingDispatch({ type: `ADD_ERROR`, error: error.message });
        })
        .finally(() => {
          loadingDispatch({ type: `LOADED` });
        });
    }
  }, [api.state.url]);

  return (
    <Loader
      state={loadingState}
      encodedEmail={props.encodedEmail}
      reportState={reports.state}
    >
      <div className={props.className}>
        <NavBar className="w5-l flex-shrink-0 mb3 br-l b--lighter-gray"/>
        {reports.state.selectedItem && <TestExplorer className="flex-auto pl4-l"/>}
      </div>
    </Loader>
  );
};

const Loader = ({
  state,
  children,
  encodedEmail,
  reportState,
}: {
  state: LoadingStore.State;
  children?: ComponentChildren;
  encodedEmail: string;
  reportState: ReportStore.State;
}) => {
  if (state.loading) {
    return (
      <div className="flex items-center justify-center br3" style={{ height: 300 }}>
        <div className="flex items-center">
          <Icon
            path="images/spinner-2.svg"
            alt="spinner"
            width="20"
            height="20"
          />
          <span className="ml1 gray">Loading test reports...</span>
        </div>
      </div>
    );
  }

  if (state.errors.length > 0) {
    return <ErrorState errors={state.errors} encodedEmail={encodedEmail}/>;
  }

  if (reportState.isEmpty) {
    return <ZeroState/>;
  }

  return <Fragment>{children}</Fragment>;
};

const ErrorState = ({ errors, encodedEmail }: { errors: string[], encodedEmail: string }) => {
  return (
    <div className="bg-washed-red br3 pa3 pa4-m ba b--black-075 mt4 flex-auto">
      <div className="flex justify-between items-center">
        <h2 className="f4 mb1 ">Test reports loading failed</h2>
        <a className="btn btn-secondary ml1" href={encodedEmail}>
          Request help
        </a>
      </div>

      <p className="mb3 measure">When loading test reports the system encountered following errors:</p>
      {errors.map((error: string) => {
        return (
          <div className="f5 code ph2 pv1 bg-washed-gray ba b--black-10 br2" key="error">
            {error}
          </div>
        );
      })}
    </div>
  );
};
