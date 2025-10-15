import { Fragment, VNode, createContext, createRef } from "preact";
import * as d3 from "d3";
import { useContext, useEffect, useLayoutEffect, useState } from "preact/hooks";
import _ from "lodash";
import * as toolbox from "js/toolbox";
import moment from "moment";
import * as stores from "../stores";

const DefaultPlotState: PlotState = {
  height: 300,
  xPos: 0,
  yPos: 0,
  margin: {
    top: 20,
    right: 40,
    bottom: 10,
    left: 70,
  },
  xScale: d3.scaleTime(),
  yScale: d3.scaleLinear(),
  width: 0,
};

const PlotContext = createContext<{ plotState: PlotState, plotData: PlotData[] }>({
  plotState: DefaultPlotState,
  plotData: [],
});

export interface PlotData {
  day: Date;
  name: string;
  value: number;
  details: Record<string, number>;
}


interface PlotState {
  width: number;
  height: number;
  xPos: number;
  yPos: number;
  margin: {
    top: number;
    right: number;
    bottom: number;
    left: number;
  };
  xScale: d3.ScaleTime<number, number>;
  yScale: d3.ScaleLinear<number, number>;
  activeDay?: Date;
}

interface PlotProps {
  className?: string;
  plotData?: PlotData[];
  children?: VNode[] | VNode;
  domain: [Date, Date];
}

export const Plot = (props: PlotProps) => {
  const plotData = props.plotData;
  const chartSVGRef = createRef<SVGSVGElement>();
  const chartContainerRef = createRef<HTMLDivElement>();

  // create a state for handling window resize
  const [resize, setResize] = useState(false);

  const [plotState, setPlotState] = useState<PlotState>({
    height: 300,
    xPos: 0,
    yPos: 0,
    margin: {
      top: 20,
      right: 60,
      bottom: 10,
      left: 70,
    },
    xScale: d3.scaleTime(),
    yScale: d3.scaleLinear(),
    width: 0,
  });

  const { dispatch: tooltipDispatch, state: tooltip } = useContext(stores.Tooltip.Context);

  // Update the resize state when the window is resized(throttled to 25ms)
  useEffect(() => {
    const throttleResize = _.throttle(() => setResize(true), 25);
    window.addEventListener(`resize`, throttleResize);
    return () => window.removeEventListener(`resize`, throttleResize);
  }, []);


  // Sync container's width with the state when the window resizes
  useLayoutEffect(() => {
    if(chartContainerRef.current) {
      const boundingRect = chartContainerRef.current.getBoundingClientRect();
      const width = boundingRect.width;

      setPlotState({ ...plotState, width: width });
      setResize(false);
    }
  }, [resize]);

  // Update the scales when new data is loaded, or the viewbox changes
  useEffect(() => {
    if(!plotState) {
      return;
    }

    if(plotState.width == 0) {
      return;
    }

    const xScale = d3.scaleTime()
      .rangeRound([plotState.margin.left, plotState.width - plotState.margin.right])
      .domain(props.domain);

    const yScale = d3.scaleLinear()
      .rangeRound([plotState.height - plotState.margin.bottom - plotState.margin.top, plotState.margin.top]);

    setPlotState({ ...plotState, xScale, yScale });
  }, [plotState.width, plotState.height, props.domain]);


  const onMouseOver = (e: MouseEvent) => {
    if(tooltip.focus)
      return;
    const x = d3.pointer(e)[0];
    let date = plotState.xScale.invert(x + 15);
    date = moment(date).startOf(`day`).toDate();
    if(!moment(date).isSameOrBefore(moment())) {
      return;
    }
    const tooltipMetrics = plotData.filter((metric) => moment(metric.day).isSame(date, `day`));


    if (moment(date).isBetween(plotState.xScale.domain()[0], plotState.xScale.domain()[1], `day`, `[]`)) {
      tooltipDispatch({ type: `SET_TOOLTIP`, x: plotState.xScale(date), y: 0, hidden: false, tooltipMetrics: tooltipMetrics, selectedDate: date });
    } else {
      tooltipDispatch({ type: `SET_TOOLTIP`, x: 0, y: 0, hidden: true, tooltipMetrics: null, selectedDate: null });
    }
  };

  const onClick = () => {
    tooltipDispatch({ type: `SET_FOCUS`, value: !tooltip.focus });
  };

  const onMouseOut = () => {
    tooltipDispatch({ type: `SET_HIDDEN`, value: true });
  };

  return (
    <div ref={chartContainerRef}>
      <svg
        ref={chartSVGRef}
        viewBox={`0 0 ${plotState.width} ${plotState.height}`}
        onMouseMove={onMouseOver}
        onMouseOut={onMouseOut}
        onClick={onClick}
        style="cursor: pointer;"
      >
        <PlotContext.Provider value={{ plotState: plotState, plotData: plotData }}>
          {props.children}
        </PlotContext.Provider>
      </svg>
    </div>
  );
};


export const DateAxisX = () => {
  const { plotState } = useContext(PlotContext);

  const xScaleRef = createRef<SVGGElement>();

  const vMargins = plotState.margin.top + plotState.margin.bottom;
  const yTranslation = plotState.height - vMargins;

  const tickScale = d3.scaleQuantize()
    .domain([200, 1000])
    .range([4, 2, 1]);

  useEffect(() => {
    if(!xScaleRef.current) {
      return;
    }
    const xAxis = d3
      .axisBottom(plotState.xScale)
      .tickSize(-yTranslation)
      .tickFormat((d) => moment(d as Date).format(`D`))
      .ticks(d3.timeDay.every(tickScale(plotState.width)));


    d3.select(xScaleRef.current)
      .call(xAxis)
      .selectAll(`line`).remove();

    d3.select(xScaleRef.current)
      .call(xAxis)
      .selectAll(`.tick text`).attr(`y`, `10`);

  }, [yTranslation, plotState.xScale]);

  return (
    <g className="x axis" style={{ cursor: `default` }} ref={xScaleRef} transform={`translate(0 ${yTranslation})`}></g>
  );
};

interface YScaleProps {
  plotData?: PlotData[];
}

export const LineChartLeft = (props: YScaleProps) => {
  const { plotState } = useContext(PlotContext);
  const plotData = props.plotData;

  const [yScale, setYScale] = useState<d3.ScaleLinear<number, number>>(null);

  const yScaleRef = createRef<SVGGElement>();

  useEffect(() => {

    const defaultYScale = d3.scaleLinear()
      .rangeRound([plotState.height - plotState.margin.bottom - plotState.margin.top, plotState.margin.top]);

    setYScale(() => defaultYScale);
  }, [plotState.height, plotState.margin]);

  useEffect(() => {
    if (!yScaleRef.current) {
      return;
    }
    if(!yScale) {
      return;
    }
    const range = calculateOptimalRange(plotData);
    const max = range.max;
    const min = Math.min(0, range.min);

    const yAxis = d3.axisRight(yScale)
      .tickSize(plotState.width - plotState.margin.left - plotState.margin.right)
      .tickFormat((d: number) => `${Math.floor(d)}`);

    const bottom = min;
    const middown = min + ((max-min)/4) * 1;
    const mid = min + ((max-min)/4) * 2;
    const midup = min + ((max-min)/4) * 3;
    const top = max;


    yScale.domain([bottom, top].map(d => Math.floor(d)));
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
  }, [yScale, plotState.width, plotData]);

  return (
    <Fragment>
      <g className="y axis" style={{ cursor: `default` }} ref={yScaleRef} transform={`translate(${plotState.width - 30} 0)`}></g>
      <LineChart plotData={plotData} yScale={yScale}/>
    </Fragment>
  );
};


export const MoneyScaleY = () => {
  const { plotState, plotData } = useContext(PlotContext);
  const yScaleRef = createRef<SVGGElement>();

  useLayoutEffect(() => {
    if (!yScaleRef.current) {
      return;
    }

    const range = calculateOptimalRange(plotData);
    const max = range.max;
    const min = Math.min(0, range.min);


    const yAxis = d3
      .axisLeft(plotState.yScale)
      .tickSize(-plotState.width)
      .tickFormat((d: number) => `${toolbox.Formatter.toMoney(Math.floor(d)).replace(`.00`, ``)}`);

    const bottom = min;
    const middown = min + ((max-min)/4) * 1;
    const mid = min + ((max-min)/4) * 2;
    const midup = min + ((max-min)/4) * 3;
    const top = max;

    plotState.yScale.domain([bottom, top].map(d => Math.floor(d)));
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
  }, [plotState.yScale, plotState.width, plotData]);

  return (
    <g className="y axis" style={{ cursor: `default` }} ref={yScaleRef} transform={`translate(50 0)`}></g>
  );
};

interface ChartProps {
  plotData?: PlotData[];
  selectedMetric?: string;
  colorScale?: (arg0: string) => string;
  className?: string;
  style?: string;
  yScale?: d3.ScaleLinear<number, number>;
  xScale?: d3.ScaleTime<number, number>;
}

export const LineChart = (props: ChartProps) => {
  const { plotState, plotData: plotContextData } = useContext(PlotContext);
  let plotData = plotContextData;
  if(props.plotData) {
    plotData = props.plotData;
  }

  const yScale = props.yScale ? props.yScale : plotState.yScale;
  const colorScale = props.colorScale ? props.colorScale : toolbox.Formatter.colorFromName;

  const lineChartRef = createRef<SVGLineElement>();
  const dotRef = createRef<SVGGElement>();

  useLayoutEffect(() => {
    if(!plotData.length) return;
    if(!plotState.xScale) return;
    if(!yScale) return;

    lineChartRef.current.replaceChildren(``);
    dotRef.current.replaceChildren(``);

    d3.select(lineChartRef.current)
      .append(`path`)
      .datum(plotData)
      .attr(`stroke-width`, 2)
      .attr(`fill`, `none`)
      .attr(`stroke`, (d) => colorScale(d[0].name))
      .attr(`pointer-events`, `visibleStroke`)
      .transition()
      .attr(`d`, d3.line<PlotData>()
        .x((d) => plotState.xScale(d.day) || 0)
        .y((d) => {
          return yScale(d.value) || 0;
        })
      );

    d3.select(dotRef.current)
      .selectAll(`g`)
      .data(plotData)
      .join(`circle`) // enter append
      .attr(`r`, `2`) // radius
      .attr(`fill`, (d) => colorScale(d.name))
      .attr(`stroke`, (d) => colorScale(d.name))
      .attr(`cx`, d => plotState.xScale(d.day) || 0) // center x passing through your xScale
      .attr(`cy`, d => yScale(d.value) || 0); // center y through your yScale

  }, [plotState.xScale, plotState.yScale, plotData]);


  return (
    <Fragment>
      <g ref={lineChartRef} className={props.className} style={props.style}/>
      <g ref={dotRef} className={props.className} style={props.style}/>
    </Fragment>
  );
};

export const TooltipLine = () => {
  const { state: tooltip } = useContext(stores.Tooltip.Context);
  const { plotState } = useContext(PlotContext);
  if(tooltip.hidden && !tooltip.focus) {
    return;
  }

  return <g>
    <line
      className={`focus-line ` + (tooltip.focus ? `focus-line--locked` : ``) }
      style="shape-rendering: cripsedges;"
      x1={tooltip.x}
      y1={plotState.yScale(plotState.yScale.domain()[1])}
      x2={tooltip.x}
      y2={plotState.yScale(plotState.yScale.domain()[0])}
      stroke={`rgb(134, 88, 214)`}
    />
  </g>;
};

//
//
// We want to have a nice distribution on the Y axis. "Nice" in this
// context means:
//
// - that we will have 5 equly distrubuted lines
// - Min value is not < 0
// - All numbers displayed are whole numbers (i.e 193 is not acceptable)
// - We only want to see "whole" numbers, 0, 10, 20, 100, 200, 300, 1000, 2000
//
function calculateOptimalRange(metrics: PlotData[]) {
  const zeroState = { min: 0, max: 20 };

  if(metrics.length == 0) {
    return zeroState;
  }

  let max = d3.max(metrics, (d: PlotData): number => Math.ceil(d.value));
  let min = d3.min(metrics, (d: PlotData): number => Math.ceil(d.value));

  if ((min == max && min == 0) || max < 20) {
    return zeroState;
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

export const StackedBar = (props: ChartProps) => {
  const { dispatch: tooltipDispatch, state: tooltip } = useContext(stores.Tooltip.Context);
  const { plotState, plotData: plotContextData } = useContext(PlotContext);
  let plotData = plotContextData;
  if(props.plotData) {
    plotData = props.plotData;
  }

  const el = createRef<SVGGElement>();
  const [min, max] = plotState.xScale.range();
  const diff = max - min;
  // The width of the bar is 2.5% of the total width of the chart
  const width = diff * 0.025;

  const hasMetricSelected = props.selectedMetric && props.selectedMetric.length > 0;

  useLayoutEffect(() => {
    // Hack - forces recreation of the rects
    // Otherwise changes on the chart are not reflected properly
    el.current.replaceChildren(``);

    const keys = _.chain(plotData)
      .flatMap(metric => Object.keys(metric.details))
      .uniq()
      .value();

    const stackGen = d3.stack()
      .keys(keys)
      .value((obj, key: string) => {
        return obj.details[key] as number;
      });


    // @ts-expect-error - d3 types are wrong
    const stackedSeries = stackGen(plotData);

    const mouseover = function() {
      if(tooltip.focus || hasMetricSelected)
        return;
      // @ts-expect-error - d3 types are wrong
      const detailName = d3.select(this.parentNode).datum().key as string;


      tooltipDispatch({ type: `SET_DETAIL_NAME`, value: detailName });
    };

    const mouseleave = function() {
      if(tooltip.focus || hasMetricSelected)
        return;

      tooltipDispatch({ type: `SET_DETAIL_NAME`, value: null });
    };

    d3.select(el.current)
      .selectAll(`g`)
      .data(stackedSeries)
      .enter().append(`g`)
      .attr(`fill`, (d) => props.colorScale(d.key))
      .attr(`class`, (d) => `chart-rect ` + d.key )
      .style(`opacity`, 0.7)
      .style(`shape-rendering`, `crispedges`)
      .selectAll(`rect`)
      .data((d) => d)
      .enter().append(`rect`)
      .attr(`x`, (d) => (plotState.xScale(d.data.day) - width / 2) || 0)
      .attr(`y`, (d) => plotState.yScale(d[1]) )
      .attr(`height`, (d) => { return Math.max(plotState.yScale(d[0]) - plotState.yScale(d[1]), 0); } )
      .attr(`width`, width)
      .on(`mouseover`, mouseover)
      .on(`mouseleave`, mouseleave);

    const detailName = props.selectedMetric;

    if(hasMetricSelected) {
      d3.selectAll(`.chart-rect`).style(`opacity`, 0.2);
      d3.selectAll(`.chart-rect.${detailName}`).style(`opacity`, 1);
    } else {
      d3.selectAll(`.chart-rect`).style(`opacity`, 0.7);
    }
  }, [plotData, plotState.xScale, plotState.yScale, tooltip.focus]);


  return (
    <g ref={el}></g>
  );
};
