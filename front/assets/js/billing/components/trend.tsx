import * as types from "../types";
import * as toolbox from "js/toolbox";

interface Trendable {
  trends: types.Spendings.Trend[];
  usageTrend: string;
  priceTrend: string;
}

enum TooltipType {
  Usage,
  Price,
}

const Icon = ({ item, type }: { item: Trendable, type: TooltipType }) => {
  const trend = type == TooltipType.Usage ? item.usageTrend : item.priceTrend;
  switch (trend) {
    case `up`:
      return <span className="pointer material-symbols-outlined green">trending_up</span>;
    case `down`:
      return <span className="pointer material-symbols-outlined red">trending_down</span>;
    case `same`:
      return <span className="pointer material-symbols-outlined">trending_flat</span>;
    default:
      return <span className="pointer material-symbols-outlined">unknown_med</span>;
  }
};

interface TooltipProps {
  item: Trendable;
  type: TooltipType;
}

const Tooltip = (props: TooltipProps) => {
  const trend = <Icon item={props.item} type={props.type}/>;
  const hasTrends = props.item.trends.length > 0;
  const trendDetails = (
    <div className="f6">
      {props.item.trends.map((trend, idx) => {
        return (
          <div className="flex justify-between" key={idx}>
            <div className="b pr2">{trend.name}</div>
            {props.type == TooltipType.Price && <div>{trend.price}</div>}
            {props.type == TooltipType.Usage && <div>{toolbox.Formatter.decimalThousands(trend.usage)}</div>}
          </div>
        );
      })}
      {hasTrends && <div>This is the historical data of your spending</div>}
      {!hasTrends && <div>This resource was not available in previous billing periods</div>}
    </div>
  );

  return <toolbox.Tooltip anchor={trend} content={trendDetails}/>;
};

export const PriceTooltip = ({ item }: { item: Trendable }) => {
  return <Tooltip item={item} type={TooltipType.Price}/>;
};

export const UsageTooltip = ({ item }: { item: Trendable }) => {
  return <Tooltip item={item} type={TooltipType.Usage}/>;
};
