
import * as stores from "../stores";
import { Status } from "../types";
import { LoadingIndicator } from "./loading_indicator";
import { Message } from "./flaky_test_table";
import { useContext, useState } from "preact/hooks";
import * as toolbox from "js/toolbox";
import { HistoryChart } from "./history_chart";


export const TopFlakyCharts = () => {
  const { state } = useContext(stores.FlakyTest.Context);

  const [flakyCumulative, setFlakyCumulative] = useState(false);
  const [disruptionCumulative, setDisruptionCumulative] = useState(true);

  return (
    <div className="flex items-center justify-between flex-wrap" id="flaky-metrics">
      <style>
        {`
          .bb-ygrid-line.goal line {
            stroke: #e53935;
          }
          .bb-ygrid-line.goal text {
            stroke: #e53935;
          }
          .bb-line {
            stroke-width: 1px;
          }
          .bb-domain {
            stroke-with: 1px;
          }
          .bb-axis line {
            stroke-opacity: 0;
          }
        `}
      </style>

      <div className="ba b--lighter-gray mb3 mr2 bg-white br3 pb3" style="width: 49.5%;">
        <div className="pa2 bb b--lighter-gray pl3 flex items-center justify-between">
          <span className="b">New flaky tests introduced</span>
          <div className="flex items-center">
            <toolbox.Tooltip
              anchor={
                <span
                  onClick={ () => setFlakyCumulative(false) }
                  className={`material-symbols-outlined pointer b ${!flakyCumulative ? `dark-gray` : `light-gray hover-dark-gray`}`}
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
                  onClick={ () => setFlakyCumulative(true) }
                  className={`material-symbols-outlined pointer b ${flakyCumulative ? `dark-gray` : `light-gray hover-dark-gray`}`}
                >
                  monitoring
                </span>}
              content={<div>Cumulative overview</div>}
              placement="top"
            />
          </div>
        </div>
        <div className="bg-white container pr4 pt3">
          {state.flakyHistoryStatus == Status.Loading && <div style="height: 200px;"><LoadingIndicator/></div>}
          {state.flakyHistoryStatus == Status.Empty &&
                <div style="height: 200px;"><Message msg="No data available."/></div>}
          {state.flakyHistoryStatus == Status.Error && <div style="height: 200px;"><Message msg="Failed to load chart data."/></div>}
          {state.flakyHistoryStatus == Status.Loaded && <HistoryChart history={state.flakyHistory} cummulative={flakyCumulative} color="#5122A5" tooltipTitle="New flaky tests" tickTitle="test"/>}
        </div>
      </div>
      <div className="ba b--lighter-gray mb3 bg-white br3 pb3" style="width: 49.5%;">
        <div className="pa2 bb b--lighter-gray b pl3 flex items-center justify-between">
          Disruptions caused by a flaky test
          <div className="flex items-center">
            <toolbox.Tooltip
              anchor={
                <span
                  onClick={ () => setDisruptionCumulative(false) }
                  className={`material-symbols-outlined pointer b ${!disruptionCumulative ? `dark-gray` : `light-gray hover-dark-gray`}`}
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
                  onClick={ () => setDisruptionCumulative(true) }
                  className={`material-symbols-outlined pointer b ${disruptionCumulative ? `dark-gray` : `light-gray hover-dark-gray`}`}
                >
                  monitoring
                </span>}
              content={<div>Cumulative overview</div>}
              placement="top"
            />
          </div>
        </div>
        <div className="bg-white container pr4 pt3">
          {state.disruptionHistoryStatus == Status.Empty &&
                <div style="height: 200px;"><Message msg="No data available."/></div>}
          {state.disruptionHistoryStatus == Status.Loading && <div style="height: 200px;"><LoadingIndicator/></div>}
          {state.disruptionHistoryStatus == Status.Error && <div style="height: 200px;"><Message msg="Failed to load chart data."/></div>}
          {state.disruptionHistoryStatus == Status.Loaded && <HistoryChart history={state.disruptionHistory} cummulative={disruptionCumulative} color="#E53935" tooltipTitle="Broken builds" tickTitle="fail"/>}
        </div>
      </div>
    </div>
  );

};
