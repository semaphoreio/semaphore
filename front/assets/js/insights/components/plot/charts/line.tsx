
import { createRef, h } from "preact";
import { useEffect } from "preact/hooks";
import * as d3 from "d3";
import * as types from "../../../types";
import { ChartInterface } from "./type";

interface Props extends ChartInterface{
  metrics: types.Chart.Metric[];
}

export default({ xScale, yScale, metrics }: Props) => {
  const lineRef = createRef<SVGLineElement>();
  useEffect(() => {
    const lineData = d3.line<types.Chart.Metric>()
      .x((d) => xScale(d.date))
      .y((d) => yScale(d.value));

    const filteredMetrics = metrics.filter((metric) => {
      return !metric.isEmpty();
    });

    d3.select(lineRef.current).data([filteredMetrics]).attr(`class`, `duration`).transition().attr(`d`, lineData);

  }, [xScale, yScale, metrics]);
  return (
    <path ref={lineRef}/>
  );
};
