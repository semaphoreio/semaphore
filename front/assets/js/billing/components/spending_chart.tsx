
import { Spendings } from "../types";
import * as stores from "../stores";
import * as types from "../types";
import * as toolbox from "js/toolbox";
import * as d3 from "d3";
import * as components from "./";
import { useContext, useLayoutEffect, useReducer, useState } from "preact/hooks";

export const SpendingChart = () => {
  const spendings = useContext(stores.Spendings.Context);
  const config = useContext(stores.Config.Context);
  const [state, dispatch] = useReducer(stores.Prices.Reducer, { ... stores.Prices.EmptyState, url: config.costsUrl } );


  const spending = spendings.state.selectedSpending;
  if(!spending)
    return;

  const groups = spending.groups || [];

  useLayoutEffect(() => {
    if(spending) {
      const url = new URL(config.costsUrl, location.origin);
      url.searchParams.set(`spending_id`, spendings.state.selectedSpendingId);

      dispatch({ type: `SET_STATUS`, value: stores.Prices.Status.Loading });
      dispatch({ type: `SET_PRICES`, prices: [] });
      fetch(url, { credentials: `same-origin` })
        .then((response) => response.json())
        .then((json) => {
          const costs = json.costs.map(types.Spendings.DailySpending.fromJSON) as types.Spendings.DailySpending[];

          dispatch({ type: `SET_PRICES`, prices: costs });
          dispatch({ type: `SET_STATUS`, value: stores.Prices.Status.Loaded });
        }).catch((e) => {
          dispatch({ type: `SET_STATUS`, value: stores.Prices.Status.Error });
          dispatch({ type: `SET_STATUS_MESSAGE`, value: `${e as string}` });
        });
    }
  }, [spending]);

  const [aggregate, setAggregate] = useState(`cumulative`);
  const initialGroupTypes = groups.map((group) => group.type);

  const [groupTypes, setGroupsTypes] = useState<Spendings.GroupType[]>(initialGroupTypes);

  const setGroup = (group: Spendings.GroupType) => {
    const index = groupTypes.indexOf(group);
    if(index == -1) {
      setGroupsTypes([...groupTypes, group]);
    } else {
      const newGroupTypes = [...groupTypes];
      newGroupTypes.splice(index, 1);
      setGroupsTypes(newGroupTypes);
    }
  };

  const setAggregateFromEvent = (event: Event) => {
    const target = event.target as HTMLSelectElement;
    const aggregate = target.value;
    setAggregate(aggregate);
  };

  const lastPriceInGroup = (type: Spendings.GroupType): string => {
    const prices = state.prices.filter((price) => price.type == type);

    if(prices.length == 0)
      return toolbox.Formatter.toMoney(0);

    return toolbox.Formatter.toMoney(prices[prices.length - 1].priceUpToDay);
  };

  return (
    <div className="shadow-1 bg-white br3 mb3">
      <div className="flex items-center justify-between pa3 bb bw1 b--black-075 br3 br--top">
        <div>
          <div className="flex items-center">
            <span className="material-symbols-outlined pr2">stacked_bar_chart</span>
            <div className="b">Spending stats <span className=" f6 gray">· {spendings.state.selectedSpending?.name}</span></div>
          </div>
        </div>
      </div>

      <div className="flex bb b--black-075">
        {groups.map((group, idx) => <SpendingGroup group={group} price={lastPriceInGroup(group.type)} lastItem={(idx + 1) == groups.length} key={idx}/>)}
      </div>
      <Chart costs={state.prices} spending={spending} aggregate={aggregate} groupTypes={groupTypes}/>

      <div className="bt b--black-075 gray pv3 ph3 flex items-center justify-between">
        <div className="flex items-center">
          <label className="mr2">Show</label>
          <select className="db form-control mb3 mb0-m mr2 form-control-tiny" value={aggregate} onChange={ setAggregateFromEvent }>
            <option value='cumulative'>Cumulative</option>
            <option value='normal'>Daily</option>
          </select>
          <span className="mr2">for</span>
          {groups.map((group, idx) => (
            <label className="flex items-center" key={idx}>
              <input type="checkbox" checked={groupTypes.includes(group.type)} onClick={ () => setGroup(group.type) }/>
              <span className="ml1 mr2">{ group.name }</span>
            </label>
          ))}
        </div>
      </div>
    </div>
  );
};

interface ChartProps {
  spending: Spendings.Spending;
  groupTypes: Spendings.GroupType[];
  aggregate: string;
  costs: Spendings.DailySpending[];
}

const Chart = ({ spending, aggregate, groupTypes, costs }: ChartProps) => {
  const [metrics, setMetrics] = useState([]);
  const [selectedCosts, setSelectedCosts] = useState<Spendings.DailySpending[]>([]);

  useLayoutEffect(() => {
    setSelectedCosts(costs.filter((cost) => groupTypes.includes(cost.type)));
  }, [costs, groupTypes]);

  useLayoutEffect(() => {
    let metrics: types.Metric.Interface[] = [];

    if(aggregate == `cumulative`) {
      metrics = selectedCosts.map((cost: Spendings.DailySpending) => {
        return {
          name: cost.type,
          date: cost.day,
          value: cost.priceUpToDay
        } as types.Metric.Interface;
      });
    }

    if(aggregate == `normal`) {
      metrics = selectedCosts.map((cost: Spendings.DailySpending) => {
        return {
          name: cost.type,
          date: cost.day,
          value: cost.price
        } as types.Metric.Interface;
      });
    }
    setMetrics(metrics);
  }, [selectedCosts, aggregate]);

  const domain = [d3.timeDay.floor(spending.from), d3.timeDay.ceil(spending.to)];


  return (
    <div className="c-billing-chart">
      <components.SpendingPlot.Plot
        domain={domain}
        metrics={metrics}
      />
    </div>
  );
};

interface SpendingGroupProps {
  group: Spendings.Group;
  price: string;
  lastItem?: boolean;
}

const SpendingGroup = ({ group, price, lastItem }: SpendingGroupProps) => {
  return (
    <div className={`w-100 b--black-075 pa3 ${lastItem ? `` : `br`}`}>
      <div className="inline-flex items-center f5">
        <div className="mr1">
          <span className="mr2 dib" style={`width:10px; height: 10px; background-color:${Spendings.Group.hexColor(group.type)}`}></span>
          {group.name}
        </div>
        <components.GroupTooltip group={group}/>
      </div>

      <div className="f4 flex items-center pv1">
        <span className="b">{price}</span>
        <components.Trend.PriceTooltip item={group}/>
      </div>
    </div>
  );
};
