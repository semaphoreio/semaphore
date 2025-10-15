import { useContext, useLayoutEffect, useReducer } from 'preact/hooks';
import { Config } from '../app';
import moment from "moment";
import * as types from '../types';
import * as stores from '../stores';
import * as plot from './plot';
import { useSearchParams } from 'react-router-dom';
import * as count from "./plot/y_axis/count";
import { handleBranchChanged, handleMetricDatePickerChanged } from "../util/event_handlers";


export const PipelineFrequency = () => {
  const { projectSummary } = useContext(stores.Summary.Context);
  const { defaultBranchName, pipelineFrequencyUrl } = useContext(Config);
  const [loading, dispatchLoading] = useReducer(stores.Loading.Reducer, stores.Loading.EmptyState);
  const [loadingCd, dispatchCdLoading] = useReducer(stores.Loading.Reducer, stores.Loading.EmptyState);
  const [{ metrics }, dispatchMetrics] = useReducer(stores.Metrics.Reducer, new types.PipelineFrequency.Metrics());
  const [cdMetrics, dispatchCdMetrics] = useReducer(stores.Metrics.Reducer, new types.PipelineFrequency.Metrics());

  const [searchParams] = useSearchParams();
  const branches = [
    { value: `default`, label: `${defaultBranchName} branch`, url: pipelineFrequencyUrl },
    { value: `all`, label: `All branches`, url: `${pipelineFrequencyUrl}?branch=all` },
  ];
  const [branchState, dispatchBranches] = useReducer(stores.Branches.Reducer, {
    branches: branches,
    activeBranch: branches.find(b => b.value === searchParams.get(`branch`)) || branches[0],
  });

  const dateRangeStore = useContext(stores.MetricDateRange.Context);
  const dateRangeState = dateRangeStore.state;

  useLayoutEffect(() => {
    const { from, to } = dateRangeState.selectedMetricDateRange;

    const url = new URL(pipelineFrequencyUrl, location.origin);
    url.searchParams.set(`cd`, `true`);
    url.searchParams.set(`from_date`, from);
    url.searchParams.set(`to_date`, to);

    dispatchCdLoading({ type: `RESET` });
    fetch(url, { credentials: `same-origin` })
      .then(response => response.json())
      .then((json: types.JSONInterface.PipelineFrequency) => {
        const state = types.PipelineFrequency.Metrics.fromJSON(json);
        dispatchCdMetrics({ type: `SET_STATE`, state });
      }).catch((e) => {
        dispatchCdLoading({ type: `ADD_ERROR`, error: e });
      }).finally(() => {
        dispatchCdLoading({ type: `LOADED` });
      });

  }, [dateRangeState.selectedMetricDateRangeLabel]);

  useLayoutEffect(() => {
    if (!branchState.activeBranch) {
      return;
    }
    const { from, to } = dateRangeState.selectedMetricDateRange;

    const url = new URL(branchState.activeBranch.url, location.origin);
    url.searchParams.set(`from_date`, from);
    url.searchParams.set(`to_date`, to);

    dispatchLoading({ type: `RESET` });
    fetch(url, { credentials: `same-origin` })
      .then(response => response.json())
      .then((json: types.JSONInterface.PipelineFrequency) => {
        const state = types.PipelineFrequency.Metrics.fromJSON(json);
        dispatchMetrics({ type: `SET_STATE`, state });
      }).catch((e) => {
        dispatchLoading({ type: `ADD_ERROR`, error: e });
      }).finally(() => {
        dispatchLoading({ type: `LOADED` });
      });
  }, [branchState.activeBranch, dateRangeState.selectedMetricDateRangeLabel]);

  return (
    <div className="w-100">
      <div className="pa4 pt4">
        <div className="inline-flex items-center">
          <p className="mb0">CI Frequency &mdash; {projectSummary.defaultBranch.pipelineFrequencyDailyCount}</p>
          <a
            className="hover-bg-washed-gray br-100 pa1 inline-flex items-center justify-center ml1 nr1 pointer"
            data-tippy-content="Change how Semaphore calculates CI Performance"
          >
          </a>
        </div>
        <div className="fr">
          <select
            className="form-control mw5 form-control-tiny"
            onChange={handleMetricDatePickerChanged(dateRangeStore.dispatch)}
            value={dateRangeState.selectedMetricDateRangeLabel}
          >
            {dateRangeState.dateRanges.map(d =>
              <option key={d.label} value={d.label}>{d.label}</option>
            )}
          </select>
        </div>

        <p className="f6 gray mb3">
          High performing teams continuously integrate their code.
          <br/>
          Keep your pull requests short, and release feature in multiple small iterations.
        </p>

        <div className="">
          <div className="shadow-1 bg-white br3">
            <div className="flex bb b--black-075">
              <div className="w-100 br b--black-075 pa3">
                <div className="inline-flex items-center f6">
                  <span>{defaultBranchName} branch</span>
                </div>
                <div className="b f3">{projectSummary.defaultBranch.pipelineFrequencyDailyCount}</div>
              </div>

              <div className="w-100 br b--black-075 pa3">
                <div className="inline-flex items-center f6">
                  <span>All branches</span>

                </div>
                <div className="f3 b">{projectSummary.allBranches.pipelineFrequencyDailyCount}</div>
              </div>
            </div>

            <div className="c-insights-chart c-insights-frequency-chart">
              <plot.Plot
                loadingState={loading}
                metrics={metrics}
                charts={[
                  <plot.charts.Area
                    metrics={metrics}
                    calculateOptimalRange={count.calculateOptimalRange}
                    height={300}
                    key="bar"
                  />,
                ]}
                tooltip={<plot.tooltips.Frequency/>}
                axisY={<plot.yAxis.Count/>}
                focus={[
                  <plot.focus.Line color="#00a569" key="line"/>,
                  <plot.focus.Dot color="#00a569" key="dot"/>,
                ]}
                xDomainFrom={moment(dateRangeState.selectedMetricDateRange.from).toDate()}
                xDomainTo={moment(dateRangeState.selectedMetricDateRange.to).toDate()}
              />
            </div>

            <div className="bt b--black-075 gray pv3 ph3 flex items-center justify-between">
              <div className="flex items-center">
                <div className="flex items-center">
                  <label className="mr2">Show</label>

                  <select
                    className="form-control w-100 mw5 form-control-tiny"
                    onChange={handleBranchChanged(branchState, dispatchBranches)}
                    value={branchState.activeBranch?.value}
                  >
                    {branchState.branches.map(branch =>
                      <option key={branch.value} value={branch.value}>{branch.label}</option>
                    )}
                  </select>
                </div>
              </div>

              <div className="gray f6">
                <div className="tr inline-flex items-center">
                  <span className="bg-green mr2 dib" style="width:7px; height: 7px;"></span>
                  <span>Number of executed pipelines</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/*CD Metrics*/}

        <div className="inline-flex items-center mt4">
          <p className="mb0">CD Frequency &mdash; {projectSummary.cdSummary.pipelineFrequencyDailyCount}</p>
          <a
            className="hover-bg-washed-gray br-100 pa1 inline-flex items-center justify-center ml1 nr1 pointer"
            data-tippy-content="Change how Semaphore calculates CI Performance"
          >
          </a>
        </div>

        <p className="f6 gray mb3">
          High performing teams continuously deploy their code.
          <br/>
          Keep your pull requests short, and release feature in multiple small iterations.
        </p>


        <div className="shadow-1 bg-white br3 mt2">
          <div className="flex bb b--black-075">
            <div className="w-100 br b--black-075 pa3">
              <div className="inline-flex items-center f6">
                <span>CD branch</span>
              </div>
              <div className="b f3">{projectSummary.cdSummary.pipelineFrequencyDailyCount}</div>
            </div>
          </div>

          <div className="c-insights-chart c-insights-frequency-chart">
            <plot.Plot
              loadingState={loadingCd}
              metrics={cdMetrics.metrics}
              charts={[
                <plot.charts.Area
                  metrics={cdMetrics.metrics}
                  calculateOptimalRange={count.calculateOptimalRange}
                  height={300}
                  key="bar"
                />,
              ]}
              tooltip={<plot.tooltips.Frequency/>}
              axisY={<plot.yAxis.Count/>}
              focus={[
                <plot.focus.Line color="#00a569" key="line"/>,
                <plot.focus.Dot color="#00a569" key="dot"/>,
              ]}
              xDomainFrom={moment(dateRangeState.selectedMetricDateRange.from).toDate()}
              xDomainTo={moment(dateRangeState.selectedMetricDateRange.to).toDate()}
            />
          </div>

          <div className="bt b--black-075 gray pv3 ph3 flex items-center justify-between">
            <div className="flex items-center">
              <div className="flex items-center">
              </div>
            </div>

            <div className="gray f6">
              <div className="tr inline-flex items-center">
                <span className="bg-green mr2 dib" style="width:7px; height: 7px;"></span>
                <span>Number of executed pipelines</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
