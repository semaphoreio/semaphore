
import { Fragment, VNode } from "preact";
import { useState, useLayoutEffect } from "preact/hooks";
import * as toolbox from "js/toolbox";
import * as types from "../types";
import * as components from "../components";
import { Item } from "../types/spendings";

interface SpendingGroupProps {
  group: types.Spendings.Group;
  footer?: VNode;
  hideUnitPrice?: boolean;
  hideUsage?: boolean;
  showItemTotalPriceTrends?: boolean;
}

export const SpendingGroup = (props: SpendingGroupProps) => {
  const displayZeroState = props.group.items.length == 0;

  const GroupItems = () => {
    if (displayZeroState) {
      return <ItemsWithZeroState group={props.group}/>;
    }
    else {
      if (props.group.isCapacityBased()) {
        return <CapacityItems group={props.group} footer={props.footer}/>;
      } else {
        return <Items group={props.group} footer={props.footer} hideUnitPrice={props.hideUnitPrice} hideUsage={props.hideUsage} showItemTotalPriceTrends={props.showItemTotalPriceTrends}/>;
      }
    }
  };

  return (
    <div className="bb b--black-075 w-100-l mb4 br3 shadow-3 bg-white">
      <div className="flex items-center justify-between pa3 bb bw1 b--black-075 br3 br--top ">
        <div>
          <div className="flex items-center">
            <i className="material-symbols-outlined pr2">{props.group.iconName}</i>
            <span className="b mr1">{props.group.name}</span>
            <components.GroupTooltip group={props.group}/>
          </div>
        </div>
      </div>
      <GroupItems/>
    </div>
  );
};

interface ItemsProps {
  group: types.Spendings.Group;
  footer?: VNode;
  hideUnitPrice?: boolean;
  hideUsage?: boolean;
  showItemTotalPriceTrends?: boolean;
}

const Items = (props: ItemsProps) => {
  const [sortedItems, setSortedItems] = useState([...props.group.items]);
  const [sortOrder, setSortOrder] = useState([``, ``]);

  useLayoutEffect(() => {
    const [sortField, sortDirection] = sortOrder;
    const sortedItems = [...props.group.items].sort((a, b) => {
      if (sortField === `name`) {
        return sortDirection === `desc` ? a.name.localeCompare(b.name) : b.name.localeCompare(a.name);
      } else if (sortField === `unitPrice`) {
        return sortDirection === `desc` ? a.rawUnitPrice - b.rawUnitPrice : b.rawUnitPrice - a.rawUnitPrice;
      } else if (sortField === `usage`) {
        return sortDirection === `desc` ? a.usage - b.usage : b.usage - a.usage;
      } else if (sortField === `price`) {
        return sortDirection === `desc` ? a.rawPrice - b.rawPrice : b.rawPrice - a.rawPrice;
      }
    });

    setSortedItems(sortedItems);
  }, [sortOrder, props.group.items]);

  const lastItemIdx = sortedItems.length - 1;
  const showTrendInSummary = props.group.showTrends;

  const summaryItem = showTrendInSummary ? sortedItems[0] : null;

  const columnFilter = (displayName: string, name: string, className: string) => {
    const isAsc = sortOrder && sortOrder[0] == name && sortOrder[1] == `asc`;
    const isDesc = sortOrder && sortOrder[0] == name && sortOrder[1] == `desc`;
    const isNone = !isAsc && !isDesc;
    let order = [``, ``];

    if (isDesc) {
      order = [``, ``];
    } else if(isAsc) {
      order = [name, `desc`];
    } else {
      order = [name, `asc`];
    }

    return (
      <div onClick={() => setSortOrder(order)} className="gray pointer" style="user-select: none;">
        <div className={`flex ${className}`}>
          <span className={ isNone ? `` : `b`}>{displayName}</span>
          {isAsc && <i className="material-symbols-outlined">expand_more</i>}
          {isDesc && <i className="material-symbols-outlined">expand_less</i>}
          {isNone && <i className="material-symbols-outlined">unfold_more</i>}
        </div>
      </div>
    );
  };

  const sortingEnabled = props.group.type == types.Spendings.GroupType.MachineTime;

  return (
    <Fragment>
      <div className="bb b--black-075">
        <div className="ph3 pv2">
          <div className="flex items-center-ns">
            <div className="w-100">
              <div className="flex-ns items-center">
                <div className="w-40-ns gray">Type</div>
                {!props.hideUnitPrice && <div className="w-20-ns tr-ns tnum gray">
                  <span>{props.group.priceLabel}</span>
                </div>}
                {!props.hideUsage && <div className="w-20-ns tr-ns tnum gray">
                  {sortingEnabled && columnFilter(props.group.usageLabel, `usage`, `justify-end`)}
                  {!sortingEnabled && props.group.usageLabel}
                </div>}
                <div className={`${props.hideUsage ? `w-60-ns` : `w-20-ns`} tr-ns tnum gray`}>
                  {sortingEnabled && columnFilter(`Total`, `price`, `justify-end`)}
                  {!sortingEnabled && `Total`}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      {sortedItems.map((item, idx) =>
        <SpendingGroupItem group={props.group} showTotalPriceTrends={props.showItemTotalPriceTrends} item={item} key={item.name} lastItem={ idx == lastItemIdx } hideUnitPrice={props.hideUnitPrice} hideUsage={props.hideUsage}/>
      )}
      <div className="pa3 bt bw1 b--black-075 w-100">
        <div className="flex items-center">
          <div className="w-60-ns">
            {props.footer}
          </div>
          {props.group.showUsage &&
            <Fragment>
              {!props.hideUsage &&
                <div className="w-20-ns tr-ns tnum">
                  <div className="flex items-center justify-end">
                    <span className="b">{toolbox.Formatter.decimalThousands(props.group.usage)}</span>
                    {showTrendInSummary && summaryItem && <components.Trend.UsageTooltip item={props.group}/>}
                  </div>
                </div>
              }
              <div className={`${props.hideUsage ? `w-40-ns` : `w-20-ns`} tr-ns tnum`}>
                <div className="b">{props.group.price}</div>
              </div>
            </Fragment>}
          {!props.group.showUsage &&
            <div className="w-40-ns tr-ns tnum">
              <div className="b">{props.group.price}</div>
            </div>
          }
        </div>
      </div>
    </Fragment>
  );
};

const CapacityItems = ({ group, footer }: ItemsProps) => {
  const [sortedItems, setSortedItems] = useState([...group.items]);
  const [sortOrder, setSortOrder] = useState([``, ``]);

  useLayoutEffect(() => {
    const [sortField, sortDirection] = sortOrder;
    const sortedItems = [...group.items].sort((a, b) => {
      if (sortField === `name`) {
        return sortDirection === `desc` ? a.name.localeCompare(b.name) : b.name.localeCompare(a.name);
      } else if (sortField === `unitPrice`) {
        return sortDirection === `desc` ? a.rawUnitPrice - b.rawUnitPrice : b.rawUnitPrice - a.rawUnitPrice;
      } else if (sortField === `usage`) {
        return sortDirection === `desc` ? a.usage - b.usage : b.usage - a.usage;
      } else if (sortField === `price`) {
        return sortDirection === `desc` ? a.rawPrice - b.rawPrice : b.rawPrice - a.rawPrice;
      }
    });

    setSortedItems(sortedItems);
  }, [sortOrder, group.items]);

  const lastItemIdx = sortedItems.length - 1;

  const showTrendInSummary = group.showTrends;
  const summaryItem = showTrendInSummary ? sortedItems[0] : null;

  const columnFilter = (displayName: string, name: string, className: string) => {
    const isAsc = sortOrder && sortOrder[0] == name && sortOrder[1] == `asc`;
    const isDesc = sortOrder && sortOrder[0] == name && sortOrder[1] == `desc`;
    const isNone = !isAsc && !isDesc;
    let order = [``, ``];

    if (isDesc) {
      order = [``, ``];
    } else if(isAsc) {
      order = [name, `desc`];
    } else {
      order = [name, `asc`];
    }

    return (
      <div onClick={() => setSortOrder(order)} className="gray pointer" style="user-select: none;">
        <div className={`flex ${className}`}>
          <span className={ isNone ? `` : `b`}>{displayName}</span>
          {isAsc && <i className="material-symbols-outlined">expand_more</i>}
          {isDesc && <i className="material-symbols-outlined">expand_less</i>}
          {isNone && <i className="material-symbols-outlined">unfold_more</i>}
        </div>
      </div>
    );
  };

  const sortingEnabled = group.type == types.Spendings.GroupType.MachineTime;

  return (
    <Fragment>
      <div className="bb b--black-075">
        <div className="ph3 pv2">
          <div className="flex items-center-ns">
            <div className="w-100">
              <div className="flex-ns items-center">
                <div className="w-80-ns gray">Type</div>
                <div className="w-20-ns tr-ns tnum gray">
                  {sortingEnabled && columnFilter(group.usageLabel, `usage`, `justify-end`)}
                  {!sortingEnabled && group.usageLabel}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      {sortedItems.map((item, idx) =>
        <SpendingGroupItem group={group} item={item} key={item.name} lastItem={ idx == lastItemIdx }/>
      )}
      <div className="pa3 bt bw1 b--black-075 w-100">
        <div className="flex items-center">
          <div className="w-60-ns">
            {footer}
          </div>
          {group.showUsage &&
            <Fragment>
              <div className="w-20-ns tr-ns tnum">
                <div className="flex items-center justify-end">
                  <span className="b">{toolbox.Formatter.decimalThousands(group.usage)}</span>
                  {showTrendInSummary && summaryItem && <components.Trend.UsageTooltip item={group}/>}
                </div>
              </div>
              <div className="w-20-ns tr-ns tnum">
                <div className="b">{group.price}</div>
              </div>
            </Fragment>
          }
          {!group.showUsage &&
            <div className="w-40-ns tr-ns tnum">
              <div className="b">{group.price}</div>
            </div>
          }
        </div>
      </div>
    </Fragment>
  );
};

const ItemsWithZeroState = ({ group }: ItemsProps) => {
  const zeroStateContent = () => {
    switch(group.type) {
      case types.Spendings.GroupType.Addon:
        return (
          <Fragment>
            <toolbox.Asset path={`images/ill-curious-girl.svg`} width={`64`} height={`94`}/>
            <h4 className="f4 mt2 mb0">No active add-ons</h4>
            <p className="f4 mb0 measure center">Contact <a href="/support">support</a> to learn more about add-ons.</p>
          </Fragment>
        );
      default:
        return (
          <Fragment>
            <toolbox.Asset path={`images/ill-curious-girl.svg`} width={`64`} height={`94`}/>
            <h4 className="f4 mt2 mb0">No active {group.name}</h4>
          </Fragment>
        );
    }
  };

  return (
    <div className="tc pt5 pb6">
      {zeroStateContent()}
    </div>
  );
};

interface SpendingGroupItemProps {
  hideUnitPrice?: boolean;
  hideUsage?: boolean;
  group: types.Spendings.Group;
  item: types.Spendings.Item;
  lastItem?: boolean;
  showTotalPriceTrends?: boolean;
}


const SpendingGroupItem = (props: SpendingGroupItemProps) => {
  const { group, item, lastItem, hideUnitPrice, hideUsage } = props;
  const [tiersExpanded, expandTiers] = useState(false);
  const bottomLine = !lastItem || (item.tiers.length > 0 && tiersExpanded);

  const ItemData = () => {

    if(group.isCapacityBased()) {
      return (
        <Fragment>
          <div className="w-80-ns">
            <div className={`flex items-center ${item.hasTiers ? `pointer` : ``}`}>
              {item.hasTiers && !tiersExpanded && <i className="material-symbols-outlined">expand_more</i>}
              {item.hasTiers && tiersExpanded && <i className="material-symbols-outlined">expand_less</i>}
              <span className="ml1">{item.name}</span>
              {item.description != `` && <span className="f6 gray ml1"> · {item.description}</span>}
            </div>
          </div>
          <div className="w-20-ns tr-ns tnum">
            <div className="flex items-center justify-end">
              {item.usage} x machines
            </div>
          </div>
        </Fragment>
      );
    } else {
      return (
        <Fragment>
          <div className="w-40-ns">
            <div className={`flex items-center ${item.hasTiers ? `pointer` : ``}`}>
              {item.hasTiers && !tiersExpanded && <i className="material-symbols-outlined">expand_more</i>}
              {item.hasTiers && tiersExpanded && <i className="material-symbols-outlined">expand_less</i>}
              <span className="ml1">{item.name}</span>
              {item.description != `` && <span className="f6 gray ml1"> · {item.description}</span>}
            </div>
          </div>
          {!hideUnitPrice && <div className="w-20-ns tr-ns tnum">{item.unitPrice}</div>}
          {!hideUsage && <div className="w-20-ns tr-ns tnum">
            <div className="flex items-center justify-end">
              {toolbox.Formatter.decimalThousands(item.usage)}
              {group.showTrends && <components.Trend.UsageTooltip item={item}/>}
            </div>
          </div>}
          <div className={`${hideUsage ? `w-60-ns` : `w-20-ns`} tr-ns tnum`}>
            <div className="flex items-center justify-end">
              {item.price}
              {props.showTotalPriceTrends && <components.Trend.PriceTooltip item={item}/>}
            </div>
          </div>
        </Fragment>
      );
    }

  };

  const ItemTierData = ({ tier }: { tier: Item, }) => {
    return (
      <Fragment>
        <div className="w-40-ns pl3">
          {tier.name}
          {tier.description != `` && <span className="f6 gray"> · {tier.description}</span>}
        </div>
        {!hideUnitPrice && <div className="w-20-ns tr-ns tnum">{tier.unitPrice}</div>}
        {!hideUsage && <div className="w-20-ns tr-ns tnum">
          <div className="flex items-center justify-end">
            {toolbox.Formatter.decimalThousands(tier.usage)}
          </div>
        </div>}
        <div className={`${hideUsage ? `w-60-ns` : `w-20-ns`} tr-ns tnum`}>{tier.price}</div>
      </Fragment>
    );
  };

  return (
    <Fragment>
      <div className={`b--black-075 ` + (bottomLine ? `bb` : ``)}>
        <div className="ph3 pv2">
          <div className="flex items-center-ns">
            <div className="w-100">
              <div className="flex-ns items-center" onClick={() => expandTiers(!tiersExpanded)}>
                <ItemData/>
              </div>
            </div>
          </div>
        </div>
      </div>
      {tiersExpanded && item.tiers.map((tier, idx) =>
        <div className={`b--black-075 ${lastItem && !(item.tiers.length - 1 != idx) ? `` : `bb`}`} key={idx}>
          <div className={`pv2 ph3`}>
            <div className="flex items-center-ns">
              <div className="w-100">
                <div className="flex-ns items-center">
                  <ItemTierData tier={tier}/>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </Fragment>
  );
};
