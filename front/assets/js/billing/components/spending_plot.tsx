import type { VNode } from "preact";
import { createRef } from "preact";
import { useEffect, useState, useLayoutEffect } from "preact/hooks";
import _ from "lodash";
import * as d3 from "d3";
import moment from "moment";
import * as toolbox from "js/toolbox";
import * as types from "../types";

interface PlotProps {
  className?: string;
  domain: Date[];
  metrics?: types.Metric.Interface[];
}

interface State {
  focusLock: boolean;
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
  metrics?: types.Metric.Interface[];
}


export const Plot = ({ domain, metrics }: PlotProps) => {
  const chartSVGRef = createRef<SVGSVGElement>();
  const chartContainerRef = createRef<HTMLDivElement>();

  // create a state for handling window resize
  const [resize, setResize] = useState(false);
  const [tooltip, setTooltip] = useState({ x: 0, y: 0, content: undefined, hidden: true });

  const [state, setState] = useState<State>({
    focusLock: false,
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
  });


  // Update the resize state when the window is resized(throttled to 50ms)
  useEffect(() => {
    const throttleResize = _.throttle(() => setResize(true), 50);
    window.addEventListener(`resize`, throttleResize);
    return () => window.removeEventListener(`resize`, throttleResize);
  }, []);


  // Sync container's width with the state when the window resizes
  useEffect(() => {
    if(chartContainerRef.current) {
      const boundingRect = chartContainerRef.current.getBoundingClientRect();
      const width = boundingRect.width;

      setState({ ...state, width: width });
      setResize(false);
    }
  }, [resize]);

  // Update the scales when new data is loaded, or the viewbox changes
  useEffect(() => {
    if(!domain.length) {
      return;
    }
    if(state.width == 0) {
      return;
    }

    const xScale = d3.scaleTime()
      .rangeRound([state.margin.left, state.width - state.margin.right])
      .domain(domain);


    const yScale = d3.scaleLinear()
      .rangeRound([state.height - state.margin.bottom - state.margin.top, state.margin.top]);

    setState({ ...state, xScale, yScale });
  }, [state.width, state.height, domain]);

  const vMargins = state.margin.top + state.margin.bottom;

  const xTranslation = state.width;
  const yTranslation = state.height - vMargins;


  return (
    <div ref={chartContainerRef}>
      <svg
        ref={chartSVGRef}
        width={state.width}
        height={state.height}
      >
        <AxisX xScale={state.xScale} translation={yTranslation}/>
        <Count
          yScale={state.yScale}
          translation={xTranslation}
          metrics={metrics}
        />
        <StackedBar
          setTooltip={setTooltip}
          tooltip={tooltip}
          metrics={metrics}
          xScale={state.xScale}
          yScale={state.yScale}
        />
      </svg>

      {!tooltip.hidden && <Tooltip
        content={tooltip.content}
        left={tooltip.x}
        top={tooltip.y}
      />}
    </div>
  );
};

interface AxisXProps {
  translation: number;
  xScale: d3.ScaleTime<number, number>;
}

const AxisX = ({ translation, xScale }: AxisXProps) => {
  const xScaleRef = createRef<SVGGElement>();

  useEffect(() => {
    if(!xScaleRef.current) {
      return;
    }
    const xAxis = d3
      .axisBottom(xScale)
      .tickSize(-translation)
      .tickFormat((d) => moment(d as Date).format(`D`))
      .ticks(d3.timeDay.every(1));


    d3.select(xScaleRef.current)
      .call(xAxis)
      .selectAll(`line`).remove();

    d3.select(xScaleRef.current)
      .call(xAxis)
      .selectAll(`.tick text`).attr(`y`, `10`);

  }, [translation, xScale]);

  return (
    <g
      className="x axis"
      style={{ cursor: `default` }}
      ref={xScaleRef}
      transform={`translate(0 ${translation})`}
    ></g>
  );
};


export const Tooltip = ({ top, left, content }: { top: number, left: number, content: VNode }) => {
  const adjustedLeft = (left: number) => {
    if (left < 2 * width) {
      left += 25;
    } else {
      left -= (width + 25);
    }

    return left;
  };

  const width = 180;
  left = adjustedLeft(left);

  return (
    <div
      className="tooltip"
      style={{
        "position": `absolute`,
        "top": top,
        "left": left,
        "width": width,
        "z-index": `3`,
      }}
    >
      {content}
    </div>
  );
};


interface CountProps {
  yScale?: d3.ScaleLinear<number, number>;
  translation?: number;
  metrics?: types.Metric.Interface[];
}

const Count = ({ yScale, translation, metrics }: CountProps) => {
  const yScaleRef = createRef<SVGGElement>();

  useLayoutEffect(() => {
    if (!yScaleRef.current) {
      return;
    }

    const range = calculateOptimalRange(metrics);
    const max = range.max;
    const min = Math.min(0, range.min);


    const yAxis = d3
      .axisLeft(yScale)
      .tickSize(-translation)
      .tickFormat((d: number) => `${toolbox.Formatter.toMoney(Math.floor(d)).replace(`.00`, ``)}`);

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
      top,
    ].map(d => Math.floor(d)));


    d3.select(yScaleRef.current)
      .call(yAxis)
      .selectAll(`.tick text`).attr(`x`, `-5`);
  }, [yScale, translation, metrics]);

  return (
    <g
      className="y axis"
      style={{ cursor: `default` }}
      ref={yScaleRef}
      transform={`translate(50 0)`}
    ></g>
  );
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
function calculateOptimalRange(metrics: types.Metric.Interface[]) {
  const zeroState = { min: 0, max: 20 };
  const combinedTypes: types.Metric.Interface[] = [];
  metrics.forEach((metric) => {
    const found = combinedTypes.find((r) => moment(r.date).isSame(metric.date, `day`));

    if(found) {
      found.value += metric.value;
    } else {
      combinedTypes.push({ ...metric });
    }
  });

  if(combinedTypes.length == 0) {
    return zeroState;
  }

  let max = d3.max(combinedTypes, (d: types.Metric.Interface): number => Math.ceil(d.value));
  let min = d3.min(combinedTypes, (d: types.Metric.Interface): number => Math.ceil(d.value));

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


interface StackedBarProps {
  metrics: types.Metric.Interface[];
  setTooltip: (tooltipData: any) => void;
  tooltip: any;

  yScale?: d3.ScaleLinear<number, number>;
  xScale?: d3.ScaleTime<number, number>;
}

const StackedBar = ({ xScale, yScale, metrics, tooltip, setTooltip }: StackedBarProps) => {
  const width = 30;
  const el = createRef<SVGGElement>();


  useEffect(() => {
    // Hack - forces recreation of the rects
    // Otherwise changes on the chart are not reflected properly
    el.current.replaceChildren(``);

    const keys = Object.values(types.Spendings.GroupType).reverse();
    const stackGen = d3.stack()
      .keys(keys)
      .value((obj, key: string) => {
        return obj.values[key] as number;
      });

    interface MetricRecord {
      date: Date;
      values: Record<string, number>;
      hexColor: string;
      total: number;
    }

    const groupedTypes: MetricRecord[] = [];
    // group metrics by name
    metrics.forEach((metric) => {
      const record: MetricRecord = { date: metric.date, hexColor: metric.hexColor, values: {}, total: metric.value };
      const found = groupedTypes.find((r) => moment(r.date).isSame(metric.date, `day`));

      if(found) {
        found.values[metric.name] = metric.value;
        found.total += metric.value;
      } else {
        record.values[metric.name] = metric.value;
        groupedTypes.push(record);
      }
    }, []);


    const mouseover = function(e: MouseEvent, d: any) {
      // @ts-expect-error - d3 types are wrong
      const subgroupName = d3.select(this.parentNode).datum().key as string;
      const data = d.data;

      const subgroupValue = data.values[subgroupName] as number;
      const chartDay = data.date as Date;
      const dayTotal = data.total as number;

      const x = xScale(chartDay);
      const y = d3.pointer(e)[1];

      setTooltip({
        ...tooltip,
        x: x,
        y: y,
        hidden: false,
        content: <div>
          <div className="f6">
            <b>{moment(chartDay).format(`MMMM Do`)}</b>
            <br/>
            Total: {toolbox.Formatter.toMoney(dayTotal)}
            <br/>
            {toolbox.Formatter.humanize(subgroupName)}: {toolbox.Formatter.toMoney(subgroupValue)}
          </div>
        </div>,
      });

      d3.selectAll(`.chart-rect`).style(`opacity`, 0.2);
      d3.selectAll(`.chart-rect.${subgroupName}`).style(`opacity`, 1);
    };

    const mouseleave = function() {
      setTooltip({
        ...tooltip,
        hidden: true,
        content: undefined,
      });

      d3.selectAll(`.chart-rect`).style(`opacity`,0.7);
    };

    // @ts-expect-error - d3 types are wrong
    const stackedSeries = stackGen(groupedTypes);


    d3.select(el.current)
      .selectAll(`g`)
      .data(stackedSeries)
      .enter().append(`g`)
      .attr(`fill`, (d) => {
        return types.Spendings.Group.hexColor(d.key as types.Spendings.GroupType);
      })
      .attr(`class`, (d) => `chart-rect ` + d.key )
      .style(`opacity`,0.7)
      .selectAll(`rect`)
      .data((d) => d)
      .enter().append(`rect`)
      .attr(`x`, (d) => xScale(d.data.date) - width / 2)
      .attr(`y`, (d) => yScale(d[1]) )
      .attr(`height`, (d) => { return yScale(d[0]) - yScale(d[1]); } )
      .attr(`width`, width)
      .on(`mouseover`, mouseover)
      .on(`mouseleave`, mouseleave);
  }, [metrics, xScale, yScale]);

  return (
    <g ref={el}></g>
  );
};
