import { cloneElement, Fragment, VNode } from 'preact';
import { useContext, useEffect, useLayoutEffect, useReducer, useState } from 'preact/hooks';
import { useSearchParams } from 'react-router-dom';
import { Config } from '../app';

import * as types from '../types';
import * as stores from '../stores';
import * as plot from './plot';
import { handleBranchChanged, handleMetricDatePickerChanged } from "../util/event_handlers";
import moment from "moment/moment";

export const PipelinePerformance = () => {
  const { projectSummary } = useContext(stores.Summary.Context);
  const dateRangeStore = useContext(stores.MetricDateRange.Context);
  const dateRangeState = dateRangeStore.state;
  const { defaultBranchName, pipelinePerformanceUrl } = useContext(Config);
  const [loading, dispatchLoading] = useReducer(stores.Loading.Reducer, stores.Loading.EmptyState);
  const [loadingCd, dispatchCdLoading] = useReducer(stores.Loading.Reducer, stores.Loading.EmptyState);
  const [metrics, dispatchMetrics] = useReducer(stores.Metrics.Reducer, new types.PipelinePerformance.Metrics());
  const [cdMetrics, dispatchCdMetrics] = useReducer(stores.Metrics.Reducer, new types.PipelinePerformance.Metrics());
  const [selectedMetrics, setSelectedMetrics] = useState([] as types.Chart.MetricWithStdDev[]);

  const [searchParams, setSearchParams] = useSearchParams();
  const branches = [
    { value: `default`, label: `${defaultBranchName} branch`, url: pipelinePerformanceUrl },
    { value: `all`, label: `All branches`, url: `${pipelinePerformanceUrl}?branch=all` },
  ];
  const [branchState, dispatchBranches] = useReducer(stores.Branches.Reducer, {
    branches: branches,
    activeBranch: branches.find(b => b.value === searchParams.get(`branch`)) || branches[0],
  });

  const [onlyPassed, setOnlyPassed] = useState(searchParams.get(`metrics`) === `passed`);
  const [activeChartId, setActiveChartId] = useState(searchParams.get(`chart`) || ``);
  const [activeCdChartId, setActiveCdChartId] = useState(searchParams.get(`cd-chart`) || ``);

  useLayoutEffect(() => {
    const { from, to } = dateRangeState.selectedMetricDateRange;

    const url = new URL(pipelinePerformanceUrl, location.origin);
    url.searchParams.set(`cd`, `true`);
    url.searchParams.set(`from_date`, from);
    url.searchParams.set(`to_date`, to);

    dispatchCdLoading({ type: `RESET` });
    fetch(url, { credentials: `same-origin` })
      .then(response => response.json())
      .then((json: types.JSONInterface.PipelinePerformance) => {
        const state = types.PipelinePerformance.Metrics.fromJSON(json);
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
      .then((json: types.JSONInterface.PipelinePerformance) => {
        const state = types.PipelinePerformance.Metrics.fromJSON(json);
        dispatchMetrics({ type: `SET_STATE`, state });
      }).catch((e) => {
        dispatchLoading({ type: `ADD_ERROR`, error: e });
      }).finally(() => {
        dispatchLoading({ type: `LOADED` });
      });

  }, [branchState.activeBranch, dateRangeState.selectedMetricDateRangeLabel]);

  useEffect(() => {
    if (onlyPassed) {
      setSelectedMetrics(metrics.passed);
    } else {
      setSelectedMetrics(metrics.all);
    }
  }, [metrics, onlyPassed]);

  const toggleActiveChart = (chartId: string) => {
    if (activeChartId === chartId) {
      setActiveChartId(``);
      searchParams.delete(`chart`);
      setSearchParams(searchParams, { replace: true });
      return;
    }

    searchParams.set(`chart`, chartId);
    setSearchParams(searchParams, { replace: true });
    setActiveChartId(chartId);
  };

  const toggleActiveCdChart = (chartId: string) => {
    if (activeCdChartId === chartId) {
      setActiveCdChartId(``);
      searchParams.delete(`cd-chart`);
      setSearchParams(searchParams, { replace: true });
      return;
    }

    searchParams.set(`cd-chart`, chartId);
    setSearchParams(searchParams, { replace: true });
    setActiveCdChartId(chartId);
  };

  const toggleOnlyPassed = () => {
    if (onlyPassed) {
      setOnlyPassed(false);
      searchParams.delete(`metrics`);
      setSearchParams(searchParams, { replace: true });
    } else {
      setOnlyPassed(true);
      searchParams.set(`metrics`, `passed`);
      setSearchParams(searchParams, { replace: true });
    }
  };

  const showChart = (chartId: string) => activeChartId == chartId || !activeChartId;
  const showCdChart = (chartId: string) => activeCdChartId == chartId || !activeCdChartId;

  return (
    <div className="w-100">
      <div className="pa4 pt4">
        <div className="inline-flex items-center w-80">
          <p className="mb0">CI Performance &mdash; {projectSummary.defaultBranch.pipelinePerformanceP50}</p>
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
                    A fast feedback loop is essential for elite performing teams.
          <br/>
                    Make sure your pipelines are fast, and have a short feedback loop.
        </p>

        <div className="">
          <div className="shadow-1 bg-white br3">
            <div className="flex bb b--black-075">
              <div className="w-100 br b--black-075 pa3">
                <div className="inline-flex items-center f6">
                  <span>{defaultBranchName} branch (p50)</span>
                </div>
                <div className="b f3">{projectSummary.defaultBranch.pipelinePerformanceP50}</div>
              </div>

              <div className="w-100 br b--black-075 pa3">
                <div className="inline-flex items-center f6">
                  <span>{defaultBranchName} branch (std.dev)</span>
                </div>
                <div className="f3 b">{projectSummary.defaultBranch.pipelinePerformanceStdDev}</div>
              </div>

              <div className="w-100 br b--black-075 pa3">
                <div className="inline-flex items-center f6">
                  <span>All pipelines (p50)</span>
                </div>
                <div className="f3 b">{projectSummary.allBranches.pipelinePerformanceP50}</div>
              </div>

              <div className="w-100 pa3">
                <div className="inline-flex items-center f6">
                  <span>All pipelines (std.dev)</span>
                </div>
                <div className="f3 b">{projectSummary.allBranches.pipelinePerformanceStdDev}</div>
              </div>
            </div>

            <div className="c-insights-chart c-insights-speed-chart">
              <plot.Plot
                loadingState={loading}
                metrics={selectedMetrics}
                charts={[
                  showChart(`duration`) ?
                    <plot.charts.Line metrics={selectedMetrics} key="duration"/> : <Fragment/>,
                  showChart(`stdDev`) ?
                    <plot.charts.StdDev
                      metrics={selectedMetrics}
                      height={300}
                      key="stdDev"
                    /> :
                    <Fragment/>,
                ]}
                tooltip={<plot.tooltips.Performance/>}
                axisY={<plot.yAxis.Duration/>}
                focus={[
                  <plot.focus.Line color="#8658d6" key="line"/>,
                  <plot.focus.Dot color="#8658d6" key="dot"/>,
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

                <div className="ml3">
                  <label className="flex items-center">
                    <input
                      type="checkbox"
                      checked={onlyPassed}
                      onClick={() => toggleOnlyPassed()}
                    />
                    <span className="ml2">Passed only</span>
                  </label>
                </div>
              </div>

              <div className="gray f6 pointer">
                <div className="tr inline-flex items-center">
                  <div
                    className="inline-flex items-center"
                    onClick={() => toggleActiveChart(`duration`)}
                  >
                    <Legend
                      icon={<span
                        className="bg-purple mr2 dib"
                        style="width:10px; height: 3px;"
                      ></span>}
                      label={<span>Duration</span>}
                      isActive={showChart(`duration`)}
                    />
                  </div>

                  <div
                    className="inline-flex items-center"
                    onClick={() => toggleActiveChart(`stdDev`)}
                  >
                    <Legend
                      icon={<span
                        className="bg-washed-purple mr2 ml3 dib"
                        style="width:10px; height: 10px;"
                      ></span>}
                      label={<span>Std Dev</span>}
                      isActive={showChart(`stdDev`)}
                    />
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/*CD Metrics*/}

          <div className="inline-flex items-center mt4">
            <p className="mb0">CD Performance &mdash; {projectSummary.cdSummary.pipelinePerformanceP50}</p>
            <a
              className="hover-bg-washed-gray br-100 pa1 inline-flex items-center justify-center ml1 nr1 pointer"
              data-tippy-content="Change how Semaphore calculates CI Performance"
            >
            </a>
          </div>

          <p className="f6 gray mb3">
                        A fast feedback loop is essential for elite performing teams.
            <br/>
                        Make sure your pipelines are fast, and have a short feedback loop.
          </p>

          <div className="shadow-1 bg-white br3 mt2">
            <div className="flex bb b--black-075">
              <div className="w-100 br b--black-075 pa3">
                <div className="inline-flex items-center f6">
                  <span>CD branch (p50)</span>
                </div>
                <div className="b f3">{projectSummary.cdSummary.pipelinePerformanceP50}</div>
              </div>

              <div className="w-100 br b--black-075 pa3">
                <div className="inline-flex items-center f6">
                  <span>CD branch (std.dev)</span>
                </div>
                <div className="f3 b">{projectSummary.cdSummary.pipelinePerformanceStdDev}</div>
              </div>


            </div>

            <div className="c-insights-chart c-insights-speed-chart">
              <plot.Plot
                loadingState={loadingCd}
                metrics={cdMetrics.all}
                charts={[
                  showCdChart(`duration`) ?
                    <plot.charts.Line metrics={cdMetrics.all} key="duration"/> : <Fragment/>,
                  showCdChart(`stdDev`) ?
                    <plot.charts.StdDev
                      metrics={cdMetrics.all}
                      height={300}
                      key="stdDev"
                    /> :
                    <Fragment/>,
                ]}
                tooltip={<plot.tooltips.Performance/>}
                axisY={<plot.yAxis.Duration/>}
                focus={[
                  <plot.focus.Line color="#8658d6" key="line"/>,
                  <plot.focus.Dot color="#8658d6" key="dot"/>,
                ]}
                xDomainFrom={moment(dateRangeState.selectedMetricDateRange.from).toDate()}
                xDomainTo={moment(dateRangeState.selectedMetricDateRange.to).toDate()}
              />
            </div>

            <div className="bt b--black-075 gray pv3 ph3 flex items-center justify-between">
              <div className="flex items-center"></div>

              <div className="gray f6 pointer">
                <div className="tr inline-flex items-center">
                  <div
                    className="inline-flex items-center"
                    onClick={() => toggleActiveCdChart(`duration`)}
                  >
                    <Legend
                      icon={<span
                        className="bg-purple mr2 dib"
                        style="width:10px; height: 3px;"
                      ></span>}
                      label={<span>Duration</span>}
                      isActive={showCdChart(`duration`)}
                    />
                  </div>

                  <div
                    className="inline-flex items-center"
                    onClick={() => toggleActiveCdChart(`stdDev`)}
                  >
                    <Legend
                      icon={<span
                        className="bg-washed-purple mr2 ml3 dib"
                        style="width:10px; height: 10px;"
                      ></span>}
                      label={<span>Std Dev</span>}
                      isActive={showCdChart(`stdDev`)}
                    />
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

const Legend = ({
  icon,
  label,
  isActive,
}: { icon: VNode<HTMLElement>, label: VNode<HTMLElement>, isActive: boolean }) => {
  let className = `o-30`;
  if (isActive) {
    className = ``;
  }

  return (
    <Fragment>
      {cloneElement(icon, { className: icon.props.className + ` ${className}` })}
      {cloneElement(label, { className: label.props.className + ` ${className}` })}
    </Fragment>
  );
};
