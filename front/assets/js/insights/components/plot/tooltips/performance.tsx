import { Fragment } from "preact";
import * as types from "../../../types";
import * as util from "../../../util";

const Summary = ({ metric }: { metric: types.PipelinePerformance.Metric }) => {
  return (
    <Fragment>
      <div className="flex justify-between">
        <div>Successful Runs</div>
        <div>{metric.passedCount}</div>
      </div>
      <div className="flex justify-between">
        <div>Failed Runs</div>
        <div>{metric.failedCount}</div>
      </div>
    </Fragment>
  );
};

interface Props {
  activeMetric?: types.PipelinePerformance.Metric;
}

export const Performance = ({ activeMetric: metric }: Props) => {
  if(!metric) {
    return;
  }

  return (
    <div>
      <strong className="f6">{util.Formatter.date(metric.date)}</strong>
      <br/>
      <div>

        <div className="flex justify-between">
          <div>Average Duration</div>
          <div>{util.Formatter.duration(metric.value)}</div>
        </div>

        <div className="flex justify-between">
          <div>Standard Deviation</div>
          <div>{util.Formatter.duration(metric.stdDev)}</div>
        </div>

        <Summary metric={metric}/>
      </div>
    </div>
  );
};
