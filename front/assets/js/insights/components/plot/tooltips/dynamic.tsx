import * as types from '../../../types';
import * as util from '../../../util';

interface Props {
  activeMetric?: types.PipelinePerformance.DynamicMetric;
}

export const Dynamic = ({ activeMetric: metric }: Props) => {
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

        <div className="flex justify-between">
          <div>P50</div>
          <div>{util.Formatter.duration(metric._p50)}</div>
        </div>

        <div className="flex justify-between">
          <div>P95</div>
          <div>{util.Formatter.duration(metric._p95)}</div>
        </div>
      </div>
    </div>
  );
};
