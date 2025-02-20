import { createRef, h } from "preact";
import { useEffect } from "preact/hooks";
import * as d3 from "d3";
import * as types from "../../../types";

interface Props {
  yScale?: d3.ScaleLinear<number, number>;
  translation?: number;
  metrics?: types.Chart.Metric[];
}

export default({ yScale, translation, metrics }: Props) => {
  const yScaleRef = createRef<SVGGElement>();

  useEffect(() => {
    if(!yScaleRef.current) {
      return;
    }

    if(metrics.length === 0) {
      return;
    }

    const range = calculateOptimalRange(metrics);
    const max = range.max;
    const min = range.min;

    const yAxis = d3
      .axisLeft(yScale)
      .tickSize(-translation + 24)
      .tickFormat((d: number) => `${Math.floor(d)}%`);

    const bottom = min;
    const middown = min + ((max-min)/4) * 1;
    const mid = min + ((max-min)/4) * 2;
    const midup = min + ((max-min)/4) * 3;
    const top = max;

    yScale.domain([bottom, top+2].map(d => Math.floor(d)));
    yAxis.tickValues([
      bottom,
      middown,
      mid,
      midup,
      top
    ].map(d => Math.floor(d)));


    d3.select(yScaleRef.current)
      .call(yAxis)
      .selectAll(`.tick text`).attr(`x`, `-5`);
  }, [yScale, translation, metrics]);

  return (
    <g className="y axis" style={{ cursor: `default` }} ref={yScaleRef}></g>
  );
};

//
// We want to have a nice distribution on the Y axis. "Nice" in this
// context means:
//
// - that we will have 5 equally distributed lines
// - Max value is not > 100
// - Min value is not < 0
// - All numbers displayed are whole numbers (i.e 92.12121% is not acceptable)
// - We only want to see "whole" numbers, 0, 10, 20, 30, ..., 90, 100
//
export function calculateOptimalRange(metrics: types.Chart.Metric[]) {
  let max = d3.max(metrics, (d: types.Chart.Metric): number => d.value);
  let min = d3.min(metrics, (d: types.Chart.Metric): number => d.value);

  const range = max - min;
  if (range == 0) {
    if (min > 0) min -= 1;
    if (max < 100) max += 1;
  }

  while(!isItNice(min, max)) {
    if(max == 100) {
      min = min - 1;
    } else {
      max = max + 1;
    }
  }

  return { min, max };
}

function isItNice(min: number, max: number) {
  const range = max - min;


  const dividesNicely = (range % 4 == 0);
  const upperValueIsRound = (max % 10 == 0);
  const bottomValueIsRound = (min % 10 == 0);

  return dividesNicely && upperValueIsRound && bottomValueIsRound;
}
