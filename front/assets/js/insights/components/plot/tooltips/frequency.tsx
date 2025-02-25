
import * as types from "../../../types";
import * as util from "../../../util";

interface Props {
  activeMetric?: types.PipelineFrequency.Metric;
}

export const Frequency = ({ activeMetric: metric }: Props) => {
  if(!metric) {
    return;
  }

  return (
    <div>
      <strong className="f6">{util.Formatter.date(metric.date)}</strong>
      <br/>
      <div hidden={metric.value === 0}>
        <div className="flex justify-between">
          <div>Total Runs</div>
          <div>{metric.value}</div>
        </div>
      </div>
      <div hidden={metric.value !== 0}>
        <div>No runs</div>
      </div>
    </div>
  );
};
