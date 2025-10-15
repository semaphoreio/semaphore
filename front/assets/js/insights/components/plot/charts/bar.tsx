
import { createRef } from "preact";
import { useEffect } from "preact/hooks";
import type * as types from "../../../types";
import * as d3 from "d3";
import type { ChartInterface } from "./type";


interface Props extends ChartInterface{
  metrics: types.Chart.Metric[];
}

export default({ xScale, yScale, metrics }: Props) => {
  const width = 10;
  const el = createRef<SVGGElement>();

  useEffect(() => {
    // Hack - forces recreation of the rects
    // Otherwise changes on the chart are not reflected properly
    el.current.replaceChildren(``);

    d3.select(el.current)
      .selectAll(`rect`)
      .data(metrics)
      .enter()
      .append(`rect`)
      .attr(`class`, `passed`)
      .attr(`y`, (d) => yScale(d.value))
      .attr(`x`, (d) => xScale(d.date) - width / 2)
      .attr(`width`, width)
      .attr(`height`, (d) => Math.max(yScale(yScale.domain()[0]) - yScale(d.value), 0));

  }, [metrics, xScale, yScale]);

  return (
    <g ref={el}></g>
  );
};
