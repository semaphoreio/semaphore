import { h } from "preact";
import * as types from "../../../types";
import * as util from "../../../util";
interface Props {
  activeMetric?: types.PipelineReliability.Metric;
}

export const Reliability = ({ activeMetric: metric }: Props) => {
  if(!metric) {
    return;
  }

  return (
    <div>
      <strong className="f6">{util.Formatter.date(metric.date)}</strong>
      <br/>
      <div hidden={metric.allCount === 0}>
        <div className="flex justify-between">
          <div>Pass Rate</div>
          <div>{metric.value}%</div>
        </div>
        <div className="flex justify-between">
          <div>All Builds</div>
          <div>{metric.allCount}</div>
        </div>
        <div className="flex justify-between">
          <div>Passed Builds</div>
          <div>{metric.passedCount}</div>
        </div>
      </div>
      <div hidden={metric.allCount !== 0}>
        <div>No builds</div>
      </div>
    </div>
  );
};
