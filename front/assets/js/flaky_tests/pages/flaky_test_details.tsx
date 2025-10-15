import { Fragment, VNode } from "preact";
import { Link, useParams } from "react-router-dom";
import * as stores from "../stores";
import * as types from "../types";
import * as components from "../components";
import { useContext, useEffect, useLayoutEffect, useReducer, useState } from "preact/hooks";
import * as toolbox from "js/toolbox";

// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";
import moment from "moment";

export const FlakyTestDetails = () => {
  const config = useContext(stores.Config.Context);
  const { testId } = useParams();

  const [state, dispatch] = useReducer(stores.FlakyTestDetail.Reducer, {
    ...stores.FlakyTestDetail.EmptyState,
  });

  const [request, dispatchRequest] = useReducer(stores.Request.Reducer, {
    url: new URL(config.flakyDetailsURL, location.origin),
    status: types.RequestStatus.Zero,
  });

  useLayoutEffect(() => {
    dispatchRequest({ type: `SET_PARAM`, name: `test_id`, value: testId });
    dispatchRequest({ type: `FETCH` });
  }, [testId]);

  useLayoutEffect(() => {
    if(request.status == types.RequestStatus.Fetch) {
      dispatchRequest({ type: `SET_STATUS`, value: types.RequestStatus.Loading });
      fetch(request.url)
        .then((response) => response.json())
        .then((json) => {
          dispatchRequest({ type: `SET_STATUS`, value: types.RequestStatus.Success });
          const test = types.Tests.FlakyDetail.fromJSON(json);
          dispatch({ type: `SET_TEST`, value: test });
        })
        .catch((e) => {
          // eslint-disable-next-line no-console
          console.error(e);
          dispatchRequest({ type: `SET_STATUS`, value: types.RequestStatus.Error });
          Notice.error(`Loading test details failed`);
        });
    }
  }, [request.status]);

  return (
    <div className="bg-washed-gray mt4 pa3 pa4-l br3 ba b--black-075">
      <div className="mb3">
        <Link to=".." className="gray">Flaky Tests Home</Link>
        <span className="ph1">›</span>
      </div>

      <stores.FlakyTestDetail.Context.Provider value={{ state, dispatch }}>
        <stores.Request.Context.Provider value={{ state: request, dispatch: dispatchRequest }}>
          <components.Loader.Container
            loadingElement={<components.Loader.LoadingSpinner text={`Loading flaky test …`}/>}
            loadingFailedElement={<components.Loader.LoadingFailed text={`Loading flaky test failed`} retry={true}/>}
          >
            <Page/>
          </components.Loader.Container>
        </stores.Request.Context.Provider>
      </stores.FlakyTestDetail.Context.Provider>
    </div>
  );
};


const Page = () => {
  const { state: { test: test } } = useContext(stores.FlakyTestDetail.Context);
  const [selectedBranch, setSelectedBranch] = useState(test.selectedContext);

  return (
    <Fragment>
      <div className="bg-white shadow-1 br3 pa3 pa4-m">
        <div className="inline-flex items-center mb3">
          <BranchSelector selectedBranch={selectedBranch} setSelectedBranch={setSelectedBranch}/>
        </div>

        <div className="mb3">
          <Info/>
        </div>

        <div className="pv3">
          <Metrics/>
        </div>

        <div className="pv3 bt b--lighter-gray">
          <DisruptionHistory/>
        </div>


        <div className="pt3 bt b--lighter-gray">
          <DisruptionDetails selectedBranch={selectedBranch}/>
        </div>
      </div>
    </Fragment>
  );
};

interface BranchSelectorProps {
  selectedBranch: string;
  setSelectedBranch: (branch: string) => void;
}

const BranchSelector = ({ selectedBranch, setSelectedBranch }: BranchSelectorProps) => {
  const { state: { test: test } } = useContext(stores.FlakyTestDetail.Context);
  const { dispatch: dispatchRequest } = useContext(stores.Request.Context);

  const [selectBranches, setSelectBranches] = useState(false);
  const [branches, setBranches] = useState([]);

  const doSelectABranch = (branch: string) => {
    setSelectedBranch(branch);
    setSelectBranches(false);
    let query = ``;
    if(branch != ``) {
      query = `@git.branch:"${branch}"`;
    }

    dispatchRequest({ type: `SET_PARAM`, name: `query`, value: encodeURIComponent(query) });
    dispatchRequest({ type: `FETCH` });
  };

  useEffect(() => {
    const branches = test.availableContexts.map((c) => {
      return {
        label: <div className="flex">
          <span className="material-symbols-outlined mr1" style="font-size: 1.5em;">fork_right</span>
          {c == selectedBranch ? <b>{c}</b> : c}
        </div>,
        value: c,
      };
    });
    branches.unshift({ label: <span>All branches</span>, value: `` });

    setBranches(branches);
  }, [selectedBranch]);

  return (
    <Fragment>
      <span className="material-symbols-outlined f5 mr1">fork_right</span>
      <span className="gray mb0 mr1">
        Showing insights for <span className="b">{selectedBranch == `` ? `all` : `${selectedBranch}`}</span> {selectedBranch == `` ? `branches` : `branch`}·
      </span>

      {!selectBranches && selectedBranch == `` && <a className="link underline pointer" onClick={() => setSelectBranches(true)}>specify a branch instead</a>}
      {!selectBranches && selectedBranch != `` && <a className="link underline pointer" onClick={() => setSelectBranches(true)}>change the branch</a>}
      {selectBranches && <components.Autocomplete items={branches} onChange={ doSelectABranch }/>}
    </Fragment>
  );
};

const Info = () => {
  const { state: { test: test } } = useContext(stores.FlakyTestDetail.Context);
  const [labels, setLabels] = useState(test.labels);

  return (
    <Fragment>
      <div className="flex items-center">
        <h1 className="f3 f2-m mb0 mr2">{test.name}</h1>
        <span className="material-symbols-outlined mr1 pointer gray hover-black" data-tippy-content="Mark this test as resolved">done_all</span>
        <span className="material-symbols-outlined mr1 pointer gray hover-dark-brown" data-tippy-content="Ticket has been created for this test">assignment_turned_in</span>
      </div>
      <p className="mb0">
        {test.file}
      </p>
      <p className="gray mb0">{test.runner}</p>
      <span className="mr1">
      Labels:
      </span>

      <div className="flex items-center">
        <components.LabelList
          testId={test.id}
          labels={labels}
          setLabels={setLabels}
          labelClass="flex items-center mr2"
        />
      </div>
    </Fragment>
  );
};

interface MetricWithTrendProps {
  data: number[];
  reverseTrend?: boolean;
  formatValue: (value: any) => string;
}

const MetricWithTrend = ({ data, reverseTrend, formatValue }: MetricWithTrendProps) => {
  const TrendValue = () => {
    let trendExists = true;
    let currentPeriod = data[0];
    let previousPeriod = data[1];

    if(previousPeriod === null) {
      trendExists = false;
      previousPeriod = 0;
    }

    if(currentPeriod === null) {
      trendExists = false;
      currentPeriod = 0;
    }

    let trendValue = previousPeriod - currentPeriod;

    let trendClass = ``;
    let trendIcon = ``;
    if(trendValue < 0) {
      trendIcon = `arrow_upward`;
    } else if(trendValue > 0) {
      trendIcon = `arrow_downward`;
    }

    if(trendValue == 0) {
      trendClass = ``;
    } else if(trendValue < 0) {
      if(reverseTrend) {
        trendClass = `red`;
      } else{
        trendClass = `green`;
      }
    } else {
      if(reverseTrend) {
        trendClass = `green`;
      } else{
        trendClass = `red`;
      }
    }

    trendValue = Math.abs(trendValue);

    return (
      <div className="flex justify-center items-center">
        {trendExists &&

            <toolbox.Tooltip
              anchor={
                <Fragment>
                  <span className={`material-symbols-outlined ${trendClass} f5`} style="font-size: 1rem;">{trendIcon}</span>
                  <span className={`${trendClass} f6`}>{formatValue(trendValue)}</span>
                </Fragment>
              }
              content={<span className="f6">Compared to the previous 30 days</span>}
            />
        }
        {!trendExists && <span className={`material-symbols-outlined gray f5`} style="font-size: 1rem;">remove</span>}
      </div>
    );
  };

  const metricValueClass = `b f3`;

  const value = data[0];
  if(value === null) {
    return (
      <Fragment>
        <span className={metricValueClass}>-</span>
        <TrendValue/>
      </Fragment>
    );
  }
  else {
    return (
      <Fragment>
        <span className={metricValueClass}>{formatValue(value)}</span>
        <TrendValue/>
      </Fragment>
    );
  }

};

interface MetricProps {
  title: string | VNode<any>;
  children: VNode<any> | VNode<any>[];
  lastElement?: boolean;
}

const Metric = ({ title, children, lastElement }: MetricProps) => {
  return (
    <div className={`ph3 flex flex-column tc ${lastElement ? `` : `br b--lightest-gray`}`}>
      <div className="flex justify-center items-center gray">
        <div className="f5">{title}</div>
      </div>
      {children}
    </div>
  );
};

const Metrics = () => {
  const { state: { test: test } } = useContext(stores.FlakyTestDetail.Context);
  const formatPercentage = (value: number): string => {
    const formattedValue = value.toFixed(2);
    return `${formattedValue}%`;
  };

  const formatDisruptions = toolbox.Formatter.decimalThousands;
  const formatRuns = (value: number) => toolbox.Pluralize(value, `run`, `runs`, (value: number) => toolbox.Formatter.decimalThousands(value));

  return (
    <Fragment>
      <div>
        <h2 className="f4">In the last 30 days</h2>
        <div className="flex-m items-center">
          <Metric title="Total runs">
            <MetricWithTrend data={test.totalCounts} formatValue={formatRuns}/>
          </Metric>

          <Metric
            title={
              <div className="flex flex-center justify-center items-center">
              Disruptions
                <toolbox.Tooltip
                  anchor={<span className="material-symbols-outlined f5 pointer ml1" style="font-size: 1rem;">info</span>}
                  content={<div className="f4">Affected {test.hashes.length} commits across {test.contexts.length} branches.</div>}
                  placement="top"
                />
              </div>
            }
          >
            <MetricWithTrend
              data={test.disruptionCount}
              formatValue={formatDisruptions}
              reverseTrend={true}
            />
          </Metric>
          <Metric
            title={
              <div className="flex flex-center justify-center items-center">
              Impact
                <toolbox.Tooltip
                  anchor={<div className="material-symbols-outlined f5 pointer ml1" style="font-size: 1rem;">help</div>}
                  content={<div className="f4">Percentage of test runs disrupted by this test.</div>}
                  placement="top"
                />
              </div>
            }
          >
            <MetricWithTrend
              data={test.impacts}
              formatValue={formatPercentage}
              reverseTrend={true}
            />
          </Metric>
          <Metric title="Pass rate">
            <MetricWithTrend
              data={test.passRates}
              formatValue={formatPercentage}
              reverseTrend={false}
            />
          </Metric>
          <Metric title="Duration (p95)" lastElement={true}>
            <MetricWithTrend
              data={test.p95Durations}
              formatValue={toolbox.Formatter.formatTestDuration}
              reverseTrend={true}
            />
          </Metric>
        </div>
      </div>
    </Fragment>
  );
};


interface DisruptionDetailsProps {
  selectedBranch: string;
}

const DisruptionDetails = ({ selectedBranch }: DisruptionDetailsProps) => {
  const config = useContext(stores.Config.Context);
  const { testId } = useParams();

  const [request, dispatchRequest] = useReducer(stores.Request.Reducer, {
    url: new URL(config.flakyDisruptionOccurencesURL, location.origin),
    status: types.RequestStatus.Zero,
  });

  const [disruptionOccurences, setDisruptionOccurences] = useState<types.Tests.DisruptionOccurence[]>([]);

  const [page, setPage] = useState(1);
  const [hasNextPage, setHasNextPage] = useState(false);

  useLayoutEffect(() => {
    let query = ``;
    if(selectedBranch != ``) {
      query = `@git.branch:"${selectedBranch}"`;
    }

    dispatchRequest({ type: `SET_PARAM`, name: `query`, value: encodeURIComponent(query) });
    dispatchRequest({ type: `SET_PARAM`, name: `test_id`, value: testId });
    setPage(1);
    dispatchRequest({ type: `FETCH` });

  }, [testId, selectedBranch]);

  useEffect(() => {
    dispatchRequest({ type: `SET_PARAM`, name: `page`, value: `${page}` });
  }, [page]);


  useLayoutEffect(() => {
    if(request.status == types.RequestStatus.Fetch) {
      dispatchRequest({ type: `SET_STATUS`, value: types.RequestStatus.Loading });
      fetch(request.url)
        .then((response) => {
          const totalPages = parseInt(response.headers.get(`X-TOTAL-PAGES`) || `1`, 10);
          if(totalPages > page) {
            setPage(page + 1);
            setHasNextPage(true);
          } else {
            setHasNextPage(false);
          }
          return response;
        })
        .then((response) => response.json())
        .then((json) => {
          dispatchRequest({ type: `SET_STATUS`, value: types.RequestStatus.Success });
          const newDisruptionOccurences = json.map(types.Tests.DisruptionOccurence.fromJSON) as types.Tests.DisruptionOccurence[];
          if(page == 1) {
            setDisruptionOccurences(newDisruptionOccurences);
          } else {
            setDisruptionOccurences(disruptionOccurences.concat(newDisruptionOccurences));
          }

        })
        .catch((e) => {
          // eslint-disable-next-line no-console
          console.error(e);
          dispatchRequest({ type: `SET_STATUS`, value: types.RequestStatus.Error });
          Notice.error(`Loading test details failed`);
        });
    }
  }, [request.status]);

  const fetchNextPage = () => {
    setHasNextPage(false);
    dispatchRequest({ type: `FETCH` });
  };

  const DisruptionOccurence = ({ item }: { item: types.Tests.DisruptionOccurence }) => {
    const humanizedDate = moment(item.timestamp).from(moment());
    return (
      <div className="flex items-center">
        <span className="material-symbols-outlined f5 mr1">fork_right</span>
        <span>{item.context}</span>
        <span className="material-symbols-outlined f5 b mh2">commit</span>
        <a
          href={item.url}
          className="measure truncate"
          title={item.workflowName}
          target="_blank"
          rel="noreferrer"
        >{item.workflowName}</a>
        <span className="ml1" title={item.timestamp?.toString()}>· {humanizedDate}, by {item.requester}</span>
      </div>
    );
  };

  return (
    <Fragment>
      <h2 className="f4 mv1">Disruption occurrences</h2>
      <div className="mb3">
        {disruptionOccurences.map((disruptionOccurrence, idx) =>
          <DisruptionOccurence item={disruptionOccurrence} key={idx}/>
        )}

        {(request.status == types.RequestStatus.Loading || request.status == types.RequestStatus.Zero) && <components.Loader.LoadingSpinner text={`Loading disruption occurrences …`}/>}
        {request.status == types.RequestStatus.Error && <components.Loader.LoadingFailed text={`Loading disruption occurrences failed`}/>}
        {hasNextPage && <a className="pointer" onClick={fetchNextPage}>+ Load more</a>}
      </div>
    </Fragment>
  );
};

const DisruptionHistory = () => {
  const { state: { test: test } } = useContext(stores.FlakyTestDetail.Context);

  const [cummulative, setCummulative] = useState(false);

  return (
    <Fragment>
      <div className="f4 mb1 mt3 flex items-center justify-between">
        <span className="b">Disruption history</span>
        <div className="flex items-center">
          <toolbox.Tooltip
            anchor={
              <span
                onClick={ () => setCummulative(false) }
                className={`material-symbols-outlined pointer b ${!cummulative ? `dark-gray` : `light-gray hover-dark-gray`}`}
              >
                  bar_chart
              </span>
            }
            content={<div>Daily overview</div>}
            placement="top"
          />

          <toolbox.Tooltip
            anchor={
              <span
                onClick={ () => setCummulative(true) }
                className={`material-symbols-outlined pointer b ${cummulative ? `dark-gray` : `light-gray hover-dark-gray`}`}
              >
                  monitoring
              </span>}
            content={<div>Cumulative overview</div>}
            placement="top"
          />
        </div>
      </div>
      <components.HistoryChart
        history={test.disruptionHistory}
        cummulative={cummulative}
        color="#E53935"
        tooltipTitle="Broken builds"
        tickTitle="fail"
      />
    </Fragment>
  );
};
