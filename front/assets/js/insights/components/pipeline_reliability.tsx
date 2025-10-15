import { useContext, useLayoutEffect, useReducer } from "preact/hooks";
import { Config } from "../app";

import * as types from "../types";
import * as stores from "../stores";
import * as plot from "./plot";
import * as util from "../util";
import { useSearchParams } from "react-router-dom";
import * as percent from "./plot/y_axis/percent";
import { handleBranchChanged, handleMetricDatePickerChanged } from "../util/event_handlers";
import moment from "moment/moment";

export const PipelineReliability = () => {
  const { projectSummary } = useContext(stores.Summary.Context);
  const dateRangeStore = useContext(stores.MetricDateRange.Context);
  const dateRangeState = dateRangeStore.state;
  const { defaultBranchName, pipelineReliabilityUrl } = useContext(Config);
  const [loading, dispatchLoading] = useReducer(stores.Loading.Reducer, stores.Loading.EmptyState);
  const [loadingCd, dispatchCdLoading] = useReducer(stores.Loading.Reducer, stores.Loading.EmptyState);
  const [{ metrics }, dispatchMetrics] = useReducer(stores.Metrics.Reducer, new types.PipelineReliability.Metrics());
  const [cdMetrics, dispatchCdMetrics] = useReducer(stores.Metrics.Reducer, new types.PipelineReliability.Metrics());

  const [searchParams] = useSearchParams();
  const branches = [
    { value: `default`, label: `${defaultBranchName} branch`, url: pipelineReliabilityUrl },
    { value: `all`, label: `All branches`, url: `${pipelineReliabilityUrl}?branch=all` },
  ];
  const [branchState, dispatchBranches] = useReducer(stores.Branches.Reducer, {
    branches: branches,
    activeBranch: branches.find((b) => b.value === searchParams.get(`branch`)) || branches[0],
  });

  useLayoutEffect(() => {
    const { from, to } = dateRangeState.selectedMetricDateRange;

    const url = new URL(pipelineReliabilityUrl, location.origin);
    url.searchParams.set(`cd`, `true`);
    url.searchParams.set(`from_date`, from);
    url.searchParams.set(`to_date`, to);

    dispatchCdLoading({ type: `RESET` });

    fetch(url, { credentials: `same-origin` })
      .then((response) => response.json())
      .then((json: types.JSONInterface.PipelineReliability) => {
        const state = types.PipelineReliability.Metrics.fromJSON(json);
        dispatchCdMetrics({ type: `SET_STATE`, state });
      })
      .catch((e) => {
        dispatchCdLoading({ type: `ADD_ERROR`, error: e });
      })
      .finally(() => {
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
      .then((response) => response.json())
      .then((json: types.JSONInterface.PipelineReliability) => {
        const state = types.PipelineReliability.Metrics.fromJSON(json);
        dispatchMetrics({ type: `SET_STATE`, state });
      })
      .catch((e) => {
        dispatchLoading({ type: `ADD_ERROR`, error: e });
      })
      .finally(() => {
        dispatchLoading({ type: `LOADED` });
      });
  }, [branchState.activeBranch, dateRangeState.selectedMetricDateRangeLabel]);

  return (
    <div id="reliability" className="w-100">
      <div className="pa4 pt4">
        <div className="inline-flex items-center">
          <p className="mb0">CI Reliability — {projectSummary.defaultBranch.pipelineReliabilityPassRate}</p>
        </div>
        <div className="fr">
          <select
            className="form-control mw5 form-control-tiny"
            onChange={handleMetricDatePickerChanged(dateRangeStore.dispatch)}
            value={dateRangeState.selectedMetricDateRangeLabel}
          >
            {dateRangeState.dateRanges.map((d) => (
              <option key={d.label} value={d.label}>
                {d.label}
              </option>
            ))}
          </select>
        </div>

        <p className="f6 gray mb3">
          A broken CI impacts the productivity of the whole team.
          <br/>
          Keep your master branch always green and ready for delivery.
        </p>

        <div className="">
          <div className="shadow-1 bg-white br3">
            <div className="flex bb b--black-075">
              <div className="w-100 br b--black-075 pa3">
                <div className="inline-flex items-center f6">
                  <span>Pass Rate</span>
                </div>
                <div className="b f3">{projectSummary.defaultBranch.pipelineReliabilityPassRate}</div>
              </div>

              <div className="w-100 br b--black-075 pa3">
                <div className="inline-flex items-center f6">
                  <span>MTTR</span>
                </div>
                <div className="f3 b">{projectSummary.defaultBranch.meanTimeToRecovery}</div>
              </div>

              <div className="w-100 pa3">
                <div className="inline-flex items-center f6">
                  <span>Last Successful Run</span>
                </div>
                <div className="f3 b" title={util.Formatter.dateTime(projectSummary.defaultBranch.projectPerformance.lastSuccessfulRunAt)}>
                  {projectSummary.defaultBranch.lastSuccessfulRun}
                </div>
              </div>
            </div>

            <div className="c-insights-chart c-insights-failure-rate-chart">
              <plot.Plot
                loadingState={loading}
                metrics={metrics}
                axisY={<plot.yAxis.Percent/>}
                tooltip={<plot.tooltips.Reliability/>}
                charts={[
                  <plot.charts.Area
                    metrics={metrics}
                    height={300}
                    calculateOptimalRange={percent.calculateOptimalRange}
                    key="bar"
                  />,
                ]}
                focus={[<plot.focus.Line color="#00a569" key="line"/>, <plot.focus.Dot color="#00a569" key="dot"/>]}
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
                    {branchState.branches.map((branch) => (
                      <option key={branch.value} value={branch.value}>
                        {branch.label}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="gray f6">
                <div className="tr">
                  <span className="bg-green mr2 dib" style="width:7px; height: 7px;"></span>
                  <span>Percentage of Passed Runs</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/*CD METRICS*/}
        <div className="inline-flex items-center mt4">
          <p className="mb0">CD Reliability — {projectSummary.cdSummary.pipelineReliabilityPassRate}</p>
        </div>

        <p className="f6 gray mb3">
          A broken CD impacts the productivity of the whole team.
          <br/>
          Keep your deployment branch always green and ready for delivery.
        </p>

        <div className="shadow-1 bg-white br3 mt2">
          <div className="flex bb b--black-075">
            <div className="w-100 br b--black-075 pa3">
              <div className="inline-flex items-center f6">
                <span>Pass Rate</span>
              </div>
              <div className="b f3">{projectSummary.cdSummary.pipelineReliabilityPassRate}</div>
            </div>

            <div className="w-100 br b--black-075 pa3">
              <div className="inline-flex items-center f6">
                <span>MTTR</span>
              </div>
              <div className="f3 b">{projectSummary.cdSummary.meanTimeToRecovery}</div>
            </div>
          </div>

          <div className="c-insights-chart c-insights-failure-rate-chart">
            <plot.Plot
              loadingState={loadingCd}
              metrics={cdMetrics.metrics}
              axisY={<plot.yAxis.Percent/>}
              tooltip={<plot.tooltips.Reliability/>}
              charts={[
                <plot.charts.Area
                  metrics={cdMetrics.metrics}
                  calculateOptimalRange={percent.calculateOptimalRange}
                  height={300}
                  key="bar"
                />,
              ]}
              focus={[<plot.focus.Line color="#00a569" key="line"/>, <plot.focus.Dot color="#00a569" key="dot"/>]}
              xDomainFrom={moment(dateRangeState.selectedMetricDateRange.from).toDate()}
              xDomainTo={moment(dateRangeState.selectedMetricDateRange.to).toDate()}
            />
          </div>

          <div className="bt b--black-075 gray pv3 ph3 flex items-center justify-between">
            <div className="flex items-center">
              <div className="flex items-center"></div>
            </div>

            <div className="gray f6">
              <div className="tr">
                <span className="bg-green mr2 dib" style="width:7px; height: 7px;"></span>
                <span>Percentage of Passed Runs</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
