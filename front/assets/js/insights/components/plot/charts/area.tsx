import { ChartInterface } from './type';
import * as types from '../../../types';
import { createRef } from 'preact';
import { useEffect } from 'preact/hooks';
import * as d3 from 'd3';

interface Props extends ChartInterface {
  height: number;
  metrics: types.Chart.Metric[];
  calculateOptimalRange: (metrics: types.Chart.Metric[]) => { min: number, max: number };
}

export default ({ xScale, yScale, height, metrics, calculateOptimalRange }: Props) => {
  const areaChart = createRef();
  useEffect(() => {
    if (!areaChart.current) {
      return;
    }

    if (metrics.length === 0) {
      return;
    }

    const range = calculateOptimalRange(metrics);
    const min = range.min;

    areaChart.current.replaceChildren(``);
    const svg = d3.select(areaChart.current)
      .attr(`height`, height);

    const area = d3.area<types.Chart.Metric>()
      .curve(d3.curveLinear)
      .x((d) => xScale(d.date))
      .y0(yScale(min))
      .y1((d) => yScale(d.value))
      .defined(d => !d.isEmpty());

    const noDef = d3.area<types.Chart.Metric>()
      .curve(d3.curveLinear)
      .x((d) => xScale(d.date))
      .y0(yScale(min))
      .y1((d) => yScale(d.value));

    // filter out empty
    const filteredMetrics = metrics.filter(m => !m.isEmpty());

    // add gray area
    svg.append(`path`)
      .attr(`fill`, `#eee`)
      .attr(`fill-opacity`, .5)
      .attr(`stroke`, `#eee`)
      .attr(`stroke-width`, 1.5)
      .attr(`d`, noDef(filteredMetrics));

    // add green area
    svg.append(`path`)
      .datum(metrics)
      .attr(`d`, area)
      .attr(`fill`, `#27ae60`)
      .attr(`fill-opacity`, .5)
      .attr(`stroke`, `#27ae60`)
      .attr(`stroke-width`, 1.5);

    // Add the dots
    svg.selectAll(`dots`)
      .data(filteredMetrics)
      .enter()
      .append(`circle`)
      .attr(`fill`, `green`)
      .attr(`stroke`, `none`)
      .attr(`cx`, (d) => xScale(d.date))
      .attr(`cy`, (d) => yScale(d.value))
      .attr(`r`, 3);

  }, [yScale, xScale, metrics]);

  return (
    <svg ref={areaChart}></svg>
  );
};
