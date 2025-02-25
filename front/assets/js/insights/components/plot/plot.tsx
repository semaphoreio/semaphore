import { cloneElement, createRef, Fragment, VNode } from "preact";
import { useEffect, useLayoutEffect, useState } from "preact/hooks";
import _ from "lodash";

import * as d3 from "d3";
import * as stores from "../../stores";
import * as types from "../../types";
import * as chart from "./index";

interface Props {
  className?: string;
  loadingState: stores.Loading.State;
  metrics: types.Chart.Metric[];
  charts: VNode[];
  axisY: VNode;
  tooltip: VNode;
  focus: VNode<chart.focus.Interface>[];
  xDomainFrom: Date;
  xDomainTo: Date;
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
  activeMetric?: types.Chart.Metric;
}

export function Plot({ charts, loadingState, axisY, metrics, tooltip, focus, xDomainFrom, xDomainTo }: Props) {
  const chartSVGRef = createRef<SVGSVGElement>();
  const chartContainerRef = createRef<HTMLDivElement>();

  // create a state for handling window resize
  const [resize, setResize] = useState(false);
  const [tooltipVisible, setTooltipVisible] = useState(false);

  const [state, setState] = useState<State>({
    focusLock: false,
    height: 300,
    xPos: 0,
    yPos: 0,
    margin: {
      top: 30,
      right: 20,
      bottom: 30,
      left: 50,
    },
    xScale: d3.scaleTime(),
    yScale: d3.scaleLinear(),
    width: 0
  });

  useLayoutEffect(() => {
    setState({ ...state, activeMetric: undefined, focusLock: false });
  }, [metrics]);

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
    if(state.width == 0) {
      return;
    }

    // //date range
    const xScale = d3.scaleTime()
      .range([0, state.width - state.margin.left - state.margin.right])
      .domain([xDomainFrom, xDomainTo]);

    const yScale = d3.scaleLinear()
      .range([state.height - state.margin.top - state.margin.bottom, 0]);

    setState({ ...state, xScale, yScale });
  }, [state.width, state.height, xDomainFrom, xDomainTo]);


  // Find the nearest metric to the mouse position
  const onMouseMove = (e: MouseEvent) => {
    if(state.focusLock) {
      return;
    }

    const bisectDate = d3.bisector((d: Date, y: Date) => y.getTime() - d.getTime()).left;
    const mouse = d3.pointer(e, chartSVGRef.current);
    const mouseDate: Date = state.xScale.invert(mouse[0] - state.margin.left);
    const i = bisectDate(metrics.map(d => d.date), mouseDate); // returns the index to the current data item

    // We're out of bounds
    if(i <= 0 || i >= metrics.length) {
      return;
    }

    const d0 = metrics[i-1];
    const d1 = metrics[i];

    const activeMetric = mouseDate.getTime() - d0.date.getTime() < d1.date.getTime() - mouseDate.getTime() ? d1 : d0;

    setState({ ...state, activeMetric });
  };

  // Update the x,y position of the mouse at the chart
  useEffect(() => {
    if(!state.activeMetric) {
      return;
    }

    const xPos = state.xScale(state.activeMetric.date) + state.margin.left;
    const yPos = state.yScale(state.activeMetric.value) + state.margin.top;

    setState({ ...state, xPos, yPos });
  }, [state.activeMetric, state.xScale, state.yScale]);

  const showTooltip = () => {
    setTooltipVisible(true);
  };

  const hideTooltip = () => {
    setTooltipVisible(false);
  };

  // Toggles focus lock. When focus lock is on, the chart will not update the active metric and the tooltip will be shown
  const toggleFocusLock = () => {
    setState({ ...state, focusLock: !state.focusLock });
  };

  const isTooltipVisible = (): boolean =>{
    return !!state.activeMetric
      && (tooltipVisible || state.focusLock)
      && !loadingState.loading
      && !(loadingState.errors.length > 0);
  };


  return (
    <div ref={chartContainerRef} onMouseLeave={hideTooltip} onMouseEnter={showTooltip}>
      {isTooltipVisible() &&
        <chart.Tooltip
          top={state.margin.top}
          left={state.xPos}
          content={tooltip}
          activeMetric={state.activeMetric}
        />}
      <ChartLoader loadingState={loadingState} metrics={metrics}/>
      <svg
        ref={chartSVGRef}
        width={state.width}
        height={state.height}
        viewBox={`0 0 ${state.width} ${state.height}`}
        onClick={() => toggleFocusLock() }
        className="pointer"
        onMouseMove={(e) => onMouseMove(e)}
      >
        <g transform={`translate(${state.margin.left}, ${state.margin.top})`}>
          <AxisX translation={state.height - state.margin.bottom - state.margin.top} xScale={state.xScale}/>
          {cloneElement(axisY, {
            translation: state.width - state.margin.left - state.margin.right,
            yScale: state.yScale,
            metrics: metrics
          })}

          {charts.map((chart) => {
            return cloneElement(chart, {
              xScale: state.xScale,
              yScale: state.yScale,
              metrics: metrics,
            });
          })}
        </g>
        {
          isTooltipVisible() &&
          focus.map((focus) => {
            return cloneElement(focus, {
              x: state.xPos,
              y: state.yPos,
              topMargin: state.margin.top,
              bottomMargin: state.height - state.margin.bottom,
              leftMargin: state.margin.left,
              rightMargin: state.width - state.margin.right - state.margin.left,
              focusLock: state.focusLock,
            });
          })
        }
      </svg>
    </div>
  );
}

const ChartLoader = ({ loadingState, metrics }: { loadingState: stores.Loading.State, metrics: types.Chart.Metric[], }) => {
  const Overlay = () => {
    return (
      <div className="bg-white o-80 mt2" style={{ width: `100%`, height: `95%`, position: `absolute`, zIndex: `1` }}>
      </div>
    );
  };

  const containerStyle = { width: `100%`, height: `100%`, position: `absolute`, zIndex: `2` };

  if (loadingState.errors.length > 0) {
    return (
      <Fragment>
        <div className="flex items-center justify-center br3" style={containerStyle}>
          <div className="flex items-center">
            <p className="ml1 tc gray">
              <span className="red">Loading chart data failed.</span>
              <br/>
              <span>Please refresh the page to try again.</span>
            </p>
          </div>
        </div>
        <Overlay/>
      </Fragment>
    );
  }

  if (!loadingState.loading && metrics.length < 2) {
    return <Fragment>
      <div className="flex items-center justify-center br3" style={containerStyle}>
        <div className="flex items-center">
          <p className="ml1 tc gray">
            <span>
              There are no insights available for this project yet.
            </span>
            <br/>
            <span className="f7 o-80">
              To display insights we need to collect the data from at least 2 days.
            </span>
          </p>
        </div>
      </div>
      <Overlay/>
    </Fragment>;
  }

  if (!loadingState.loading) {
    return;
  }

  return (
    <Fragment>
      <div className="flex items-center justify-center br3" style={containerStyle}>
        <div className="flex items-center">
          <img src="/projects/assets/images/spinner-2.svg" style="width: 20px; height: 20px;"/>
          <span className="ml1 gray">Chart data is loading, please wait&hellip;</span>
        </div>
      </div>
      <Overlay/>
    </Fragment>
  );
};

const AxisX = ({ translation, xScale }: { translation: number, xScale: d3.ScaleTime<number, number>, }) => {
  const xScaleRef = createRef<SVGGElement>();
  useEffect(() => {
    if(xScaleRef.current) {
      const xAxis = d3
        .axisBottom(xScale)
        .tickSize(-translation)
        .tickFormat((d) => d3.timeFormat(`%b %d`)(d as Date));

      d3.select(xScaleRef.current)
        .call(xAxis)
        .selectAll(`.tick text`).attr(`y`, `10`);
    }
  }, [translation, xScale]);

  return (
    <g className="x axis" style={{ cursor: `default` }} ref={xScaleRef} transform={`translate(0, ${translation})`}></g>
  );
};
