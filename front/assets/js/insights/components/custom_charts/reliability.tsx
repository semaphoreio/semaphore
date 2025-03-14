import * as plot from '../plot';
import * as percent from "../plot/y_axis/percent";
import moment from "moment";
import { useContext } from "preact/hooks";
import * as stores from "../../stores";

interface Props {
  metrics: any;
  branchName: string;
  pipelineFileName: string;
}

export const Reliability = ({ metrics, branchName, pipelineFileName }: Props) => {
  const dateRangeStore = useContext(stores.MetricDateRange.Context);
  const dateRangeState = dateRangeStore.state;

  return (
    <div className="c-insights-chart c-insights-failure-rate-chart">
      <plot.Plot
        loadingState={{ loading: false, errors: [] }}
        metrics={metrics}
        axisY={<plot.yAxis.Percent/>}
        tooltip={<plot.tooltips.Reliability/>}
        charts={[
          <plot.charts.Area metrics={metrics} calculateOptimalRange={percent.calculateOptimalRange} height={300} key="bar"/>
        ]}
        focus={[
          <plot.focus.Line color="#00a569" key="line"/>,
          <plot.focus.Dot color="#00a569" key="dot"/>
        ]}
        xDomainFrom={moment(dateRangeState.selectedMetricDateRange.from).toDate()}
        xDomainTo={moment(dateRangeState.selectedMetricDateRange.to).toDate()}
      />
      <div className="bt b--black-075 gray pv3 ph3 flex items-center justify-between">
        <div className="flex items-center">
          {/*this icon needs to be loaded dynamically */}
          <img src="/projects/assets/images/icn-branch.svg"
            className="flex-shrink-0 mr2 dn db-l" width="16" height="16" alt="branch icon"/>
          <label className="mr2">{branchName}</label>

          {/*this icon needs to be loaded dynamically */}
          <img src="/projects/assets/images/icn-commit.svg"
            className="flex-shrink-0 mr2 dn db-l"
            width="16" height="16" alt="pipeline icon"/>
          <label className="mr2">{pipelineFileName}</label>
        </div>
      </div>
    </div>
  );
};
