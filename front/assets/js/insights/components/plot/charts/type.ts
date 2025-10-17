import type * as d3 from "d3";
export interface ChartInterface {
  yScale?: d3.ScaleLinear<number, number>;
  xScale?: d3.ScaleTime<number, number>;
}
