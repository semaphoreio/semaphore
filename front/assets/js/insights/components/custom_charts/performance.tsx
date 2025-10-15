import * as plot from '../plot';
import { cloneElement, Fragment, VNode } from 'preact';
import { useContext, useState } from "preact/hooks";
import { useSearchParams } from "react-router-dom";
import { DashboardItem } from "../../types/dashboard";
import * as stores from "../../stores";
import moment from "moment";

interface Props {
  metrics: any;
  item: DashboardItem;
}


export const Performance = ({ metrics, item }: Props) => {
  const dateRangeStore = useContext(stores.MetricDateRange.Context);
  const dateRangeState = dateRangeStore.state;

  const [searchParams, setSearchParams] = useSearchParams();
  const chartHash = item.id;
  const [activeChartId, setActiveChartId] = useState(searchParams.get(`chart_${chartHash}`) || ``);
  const toggleActiveChart = (chartId: string) => {
    if (activeChartId === chartId) {
      setActiveChartId(``);
      searchParams.delete(`chart_${chartHash}`);
      setSearchParams(searchParams, { replace: true });
      return;
    }

    searchParams.set(`chart_${chartHash}`, chartId);
    setSearchParams(searchParams, { replace: true });
    setActiveChartId(chartId);
  };

  const showChart = (chartId: string) => activeChartId == chartId || !activeChartId;

  return (
    <div className="c-insights-chart c-insights-speed-chart">
      <plot.Plot
        loadingState={{ loading: false, errors: [] }}
        metrics={metrics}
        charts={[
          showChart(`duration`) ? <plot.charts.Line metrics={metrics} key="duration"/> : <Fragment/>,
          showChart(`stdDev`) ? <plot.charts.StdDev metrics={metrics} height={300} key="stdDev"/> :
            <Fragment/>,
          showChart(`mean`) ? <plot.charts.Line metrics={metrics} key="mean"/> : <Fragment/>
        ]}
        tooltip={<plot.tooltips.Dynamic/>}
        axisY={<plot.yAxis.Duration/>}
        focus={[
          <plot.focus.Line color="#8658d6" key="line"/>,
          <plot.focus.Dot color="#8658d6" key="dot"/>
        ]}
        xDomainFrom={moment(dateRangeState.selectedMetricDateRange.from).toDate()}
        xDomainTo={moment(dateRangeState.selectedMetricDateRange.to).toDate()}
      />
      <div className="bt b--black-075 gray pv3 ph3 flex items-center justify-between">
        <div className="flex items-center">
          {/*this icon needs to be loaded dynamically */}
          <img src="/projects/assets/images/icn-branch.svg"
            className="flex-shrink-0 mr2 dn db-l" width="16" height="16" alt="branch icon"/>
          <label className="mr2">{item.branchName}</label>

          {/*this icon needs to be loaded dynamically */}
          <img src="/projects/assets/images/icn-commit.svg"
            className="flex-shrink-0 mr2 dn db-l"
            width="16" height="16" alt="pipeline icon"/>
          <label className="mr2">{item.pipelineFileName}</label>
        </div>

        <div className="gray f6 pointer">
          <div className="tr inline-flex items-center">
            <div className="inline-flex items-center" onClick={() => toggleActiveChart(`duration`)}>
              <Legend
                icon={<span className="bg-purple mr2 dib" style="width:10px; height: 3px;"></span>}
                label={<span>Duration</span>}
                isActive={showChart(`duration`)}
              />
            </div>

            <div className="inline-flex items-center" onClick={() => toggleActiveChart(`stdDev`)}>
              <Legend
                icon={<span className="bg-washed-purple mr2 ml3 dib" style="width:10px; height: 10px;"></span>}
                label={<span>Std Dev</span>}
                isActive={showChart(`stdDev`)}
              />
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
  isActive
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
