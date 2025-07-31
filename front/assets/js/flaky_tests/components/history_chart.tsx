import { Fragment, createRef } from "preact";
import bb, { bar } from "billboard.js";
import { HistoryItem } from "../types/flaky_test_item";
import { useEffect } from "preact/hooks";
import { ChartHelpers } from "js/toolbox";
import * as toolbox from "js/toolbox";


export const HistoryChart = ({ history, cummulative, color, tooltipTitle, tickTitle }: { history: HistoryItem[], cummulative: boolean, color: string, tooltipTitle: string, tickTitle: string, }) => {
  const ref = createRef();

  useEffect(() => {
    const dates = history.map(i => i.day.toString());

    let cummulativeSum = 0;
    const counts = history.map((i) => {
      if(cummulative) {
        cummulativeSum += i.count;
      } else {
        cummulativeSum = i.count;
      }
      return cummulativeSum;
    });

    const axisValues = ChartHelpers.CalculateOptimalRange(counts);
    const max = Math.max(...axisValues);

    const colors: { [key: string]: string, } = {};
    colors[tooltipTitle] = color;

    const chart = bb.generate({
      bindto: ref.current,
      size: {
        height: 200
      },
      data: {
        x: `date`,
        columns: [
          [`date`].concat(dates),
          [tooltipTitle].concat(counts.map(i => i.toString(10)))
        ],
        type: bar(),
        colors
      },
      legend: {
        show: false
      },
      axis: {
        x: {
          type: `timeseries`,
          tick: {
            format: `%b-%d`,
          }
        },
        y: {
          max: max,
          tick: {
            values: axisValues,
            count: axisValues.length,
            format: function (d: number) {
              return toolbox.Pluralize(d, tickTitle, `${tickTitle}s`);
            }
          }
        }
      },
      grid: {
        y: {
          show: true,
        }
      }
    });

    return (() => {chart.destroy();});
  }, [history, cummulative]);

  return (
    <Fragment>
      <style>
        {`
          .bb-ygrid-line.goal line {
            stroke: #e53935;
          }
          .bb-ygrid-line.goal text {
            stroke: #e53935;
          }
          .bb-line {
            stroke-width: 1px;
          }
          .bb-domain {
            stroke-with: 1px;
          }
          .bb-axis line {
            stroke-opacity: 0;
          }
        `}
      </style>
      <div ref={ref} className="c3"style="max-height: 200px; position: relative; border-bottom: none;">
      </div>
    </Fragment>
  );
};
