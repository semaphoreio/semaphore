import { createRef } from "preact";
import { useEffect } from "preact/hooks";
import * as d3 from "d3";
import type * as types from "../../../types";

interface Props {
  yScale?: d3.ScaleLinear<number, number>;
  translation?: number;
  metrics?: types.Chart.Metric[];
}

export default ({ yScale, translation, metrics }: Props) => {
  const yScaleRef = createRef<SVGGElement>();

  useEffect(() => {
    if (!yScaleRef.current) {
      return;
    }

    if (metrics.length === 0) {
      return;
    }

    const maxY =
      d3.max(metrics, (d: types.Chart.Metric): number => d.value * 1.05) || 0;

    const yAxis = d3
      .axisLeft(yScale)
      .tickSize(-translation + 24)
      .tickFormat((d: d3.NumberValue) => `${Math.floor((d as number) / 60)}'`);

    if (maxY < 4 * 60) {
      yScale.domain([0, 4 * 60]);
      yAxis.tickValues([0, 1 * 60, 2 * 60, 3 * 60, 4 * 60]);
    } else if (maxY < 8 * 60) {
      yScale.domain([0, 8 * 60]);
      yAxis.tickValues([0, 2 * 60, 4 * 60, 6 * 60, 8 * 60]);
    } else if (maxY < 12 * 60) {
      yScale.domain([0, 16 * 60]);
      yAxis.tickValues([0, 4 * 60, 8 * 60, 12 * 60, 16 * 60]);
    } else if (maxY < 20 * 60) {
      yScale.domain([0, 20 * 60]);
      yAxis.tickValues([0, 5 * 60, 10 * 60, 15 * 60, 20 * 60]);
    } else if (maxY < 40 * 60) {
      yScale.domain([0, 40 * 60]);
      yAxis.tickValues([0, 10 * 60, 20 * 60, 30 * 60, 40 * 60]);
    } else if (maxY > 30 * 60 && maxY < 60 * 60) {
      yScale.domain([0, 60 * 60]);
      yAxis.tickValues([0, 15 * 60, 30 * 60, 45 * 60, 60 * 60]);
    } else {
      const oneMinute = 60;
      let maxMinutes = maxY / oneMinute;
      maxMinutes = Math.ceil(maxMinutes / 10) * 10;
      let tickSize = Math.ceil(Math.ceil(maxMinutes / 5) / 20) * 20;
      tickSize = tickSize * oneMinute;

      yScale.domain([0, 4 * tickSize]);
      yAxis.tickValues([
        0,
        1 * tickSize,
        2 * tickSize,
        3 * tickSize,
        4 * tickSize,
      ]);
    }

    d3.select(yScaleRef.current)
      .call(yAxis)
      .selectAll(`.tick text`)
      .attr(`x`, `-10`);
  }, [yScale, translation, metrics]);

  return (
    <g
      className="y axis"
      style={{ cursor: `default` }}
      ref={yScaleRef}
    ></g>
  );
};
