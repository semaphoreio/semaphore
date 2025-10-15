import { createRef } from 'preact';
import { useEffect } from 'preact/hooks';
import * as d3 from 'd3';
import * as types from '../../../types';

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

    const range = calculateOptimalRange(metrics);
    const max = range.max;
    const min = range.min;

    const yAxis = d3
      .axisLeft(yScale)
      .tickSize(-translation + 24)
      .tickFormat((d: number) => `${Math.floor(d)}`);

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
      top,
    ].map(d => Math.floor(d)));


    d3.select(yScaleRef.current)
      .call(yAxis)
      .selectAll(`.tick text`).attr(`x`, `-10`);
  }, [yScale, translation, metrics]);

  return (
    <g
      className="y axis"
      style={{ cursor: `default` }}
      ref={yScaleRef}
    ></g>
  );
};

//
//
// We want to have a nice distribution on the Y axis. "Nice" in this
// context means:
//
// - that we will have 5 equally distributed lines
// - Min value is not < 0
// - All numbers displayed are whole numbers (i.e 193 is not acceptable)
// - We only want to see "whole" numbers, 0, 10, 20, 100, 200, 300, 1000, 2000
//
export function calculateOptimalRange(metrics: types.Chart.Metric[]) {
  let max = d3.max(metrics, (d: types.Chart.Metric): number => d.value);
  let min = d3.min(metrics, (d: types.Chart.Metric): number => d.value);

  if (max - min == 0) {
    max = max + 5;
  }

  while(!isItNice(min, max)) {
    if(min == 0) {
      max = max + 1;
    } else {
      min = min - 1;
    }
  }

  return { min, max };
}

function isItNice(min: number, max: number) {
  const range = max - min;

  const dividesNicely = (range % 4 == 0);
  const upperValueIsRound = isOneNumberAllZeros(max);
  const bottomValueIsRound = isOneNumberAllZeros(min);

  return dividesNicely && upperValueIsRound && bottomValueIsRound;
}

//
// Example:
//
// 0  -> true
// 8  -> true
// 18 -> false
// 20 -> true
// 81 -> false
// 100 -> true
// 112 -> false
// 110 -> false
// 200 -> true
//
function isOneNumberAllZeros(value: number) {
  const digits = value.toString().length;
  const divisor = Math.pow(10, digits-1);

  return value % divisor == 0;
}
