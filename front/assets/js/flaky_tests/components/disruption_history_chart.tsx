import { createRef } from "preact";
import bb, { bar } from "billboard.js";
import { HistoryItem } from "../types/flaky_test_item";
import { useEffect } from "preact/hooks";


export interface DisruptionHistoryChartProps {
  items: HistoryItem[];
}
export const DisruptionHistoryChart = (props: DisruptionHistoryChartProps) => {
  const dates = props.items.map(i => i.day.toString());
  const counts = props.items.map(i => i.count.toString(10));
  const ref = createRef();

  useEffect(() => {
    const target = ref.current as HTMLElement;
    const chart = bb.generate({
      bindto: target,
      size: {
        height: 50
      },
      data: {
        x: `date`,
        columns: [
          [`date`].concat(dates),
          [`Broken builds`].concat(counts)
        ],
        type: bar(),
        colors: {
          'Broken builds': `#e53935`
        }
      },
      legend: {
        show: false
      },
      axis: {
        x: {
          show: false,
          type: `timeseries`,
          tick: {
            format: `%b-%d`,
          }
        },
        y: {
          show: false,
          tick: {
            format: function (d: number) { return `${d} fails`; }
          }
        }
      },
      grid: {
        y: {
          show: false,
        }
      }
    });

    return (() => chart.destroy());
  }, []);

  return (
    <div ref={ref} className="w-80-m b--light-gray" style="position: relative;"></div>
  );
};
