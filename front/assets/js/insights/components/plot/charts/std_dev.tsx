

import { createRef, h } from "preact";
import { useEffect } from "preact/hooks";
import * as d3 from "d3";
import * as types from "../../../types";
import { ChartInterface } from "./type";


interface Props extends ChartInterface{
  height: number;
  metrics: types.Chart.MetricWithStdDev[];
}


export default({ metrics, height, xScale, yScale, }: Props) => {
  const deviationRef = createRef<SVGPathElement>();
  useEffect(() => {
    if(metrics.length == 0) {
      return;
    }
    const stdDevLineData: types.Chart.MetricWithStdDev[] = [];

    metrics.forEach(d => {
      stdDevLineData.push({ ...d, date: d.date, value: d.value + d.stdDev });
    });

    metrics.forEach(d => {
      const value = d.value - d.stdDev < 0 ? 0 : d.value - d.stdDev;
      stdDevLineData.unshift({ ...d, date: d.date, value: value });
    });

    const shapeData = d3.line<types.Chart.MetricWithStdDev>()
      .x(d => xScale(d.date))
      .y(d => { return Math.min(Math.max(yScale(d.value), 0), height); });

    d3.select(deviationRef.current).data([stdDevLineData]).transition().attr(`d`, shapeData);
  }, [metrics, xScale, yScale, height]);

  return (
    <path className="deviation" ref={deviationRef}/>
  );
};
