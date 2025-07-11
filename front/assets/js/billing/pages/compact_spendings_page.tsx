import { Fragment } from "preact";
import * as stores from "../stores";
import * as types from "../types";
import * as components from "../components";
import * as toolbox from "js/toolbox";

import { useContext, useLayoutEffect, useState } from "preact/hooks";

export const CompactSpendingsPage = () => {
  const { state } = useContext(stores.Spendings.Context);
  const spending = state.selectedSpending;

  if (!spending)
    return;

  return (
    <div className="w-60 center">
      <PlanInfo spending={spending}/>
      <div className="bb b--black-075 w-100-l mb4 br3 shadow-3 bg-white">
        <div className="flex items-center justify-between pa3 bb bw1 b--black-075 br3 br--top ">
          <div>
            <div className="flex items-center">
              <span className="material-symbols-outlined pr2">dns</span>
              <div className="b mr1">Machines available</div>
              <components.GroupTooltip group={spending.getGroup(types.Spendings.GroupType.MachineCapacity)}/>
            </div>
          </div>
        </div>
        <MachineInfo spending={spending}/>
        <div className="pa3 bt bw1 b--black-075 w-100">
          <span className="b">Want to make changes to your plan?</span> – Contact your <a href="mailto:customersuccess@semaphoreci.com">customer success</a> representative.
        </div>
      </div>
    </div>
  );
};

const MachineInfo = ({ spending }: { spending?: types.Spendings.Spending, }) => {
  if (!spending) {
    return null;
  }

  const groupType = types.Spendings.GroupType.MachineCapacity;

  const [sortedItems, setSortedItems] = useState([...spending.getGroup(groupType).items]);
  const [sortOrder, setSortOrder] = useState([``, ``]);

  useLayoutEffect(() => {
    const group = spending.getGroup(groupType);

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
  }, [sortOrder, spending]);

  const columnFilter = (displayName: string, name: string, className?: string) => {
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

  return (
    <Fragment>
      <div className="bb b--black-075">
        <div className="ph4 pv2">
          <div className="flex items-center">
            <div className="w-100">
              <div className="flex items-center">
                <div className="w-60 gray">{columnFilter(`Type`, `name`)}</div>
                <div className="w-40 tr tnum gray">{columnFilter(`Capacity`, `usage`, `justify-end`)}</div>
              </div>
            </div>
          </div>
        </div>
      </div>
      {sortedItems.length == 0 && <div className="pa3 tc">No machines available</div>}
      {sortedItems.map((machine, idx) => <MachineItem machine={machine} lastItem={ idx == sortedItems.length - 1 } key={idx}/>)}
    </Fragment>
  );
};

const MachineItem = ({ machine, lastItem }: { machine: types.Spendings.Item, lastItem?: boolean, }) => {
  return (
    <div className={`hover-bg-washed-gray ${lastItem ? `` : `bb b--black-075`}`}>
      <div className="ph4 pv2">
        <div className="flex items-center">
          <div className="w-100">
            <div className="flex items-center">
              <div className="w-60 flex items-center">
                <span>{machine.name}</span>
                {machine.description != `` && <span className="f6 gray ml1"> · {machine.description}</span>}
              </div>
              <div className="w-40 tr tnum">{machine.usage} x machines</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

const PlanInfo = ({ spending }: { spending?: types.Spendings.Spending, }) => {
  if (!spending) {
    return null;
  }

  const plan = spending.plan;


  const planDescription = () => {
    switch(plan.type) {
      case types.Spendings.PlanType.Flat:
        return `Unlimited minutes, fixed annual charge.`;
      case types.Spendings.PlanType.Grandfathered:
        return `Fixed monthly subscription from Semaphore Classic.`;
    }
  };

  const planName = () => {
    switch(plan.type) {
      case types.Spendings.PlanType.Flat:
        return `Flat plan`;
      case types.Spendings.PlanType.Grandfathered:
        return `Grandfathered plan`;
    }
  };

  const planDetails = () => {
    switch(plan.type) {
      case types.Spendings.PlanType.Flat:
        if(!plan.subscriptionEndsOn) {
          return;
        }

        return (
          <div>
            <div className="inline-flex items-center">
              <p className="mb0 tr mr1">Ends on: <span className="b">{toolbox.Formatter.dateFull(plan.subscriptionEndsOn)}</span></p>
            </div>
          </div>
        );
      case types.Spendings.PlanType.Grandfathered:
        return (
          <div>
            <div className="inline-flex items-center">
              Access your Semaphore Classic account to see previous invoices.
            </div>
          </div>
        );
    }
  };


  return (
    <div className="flex items-center justify-between">
      <div>
        <div className="inline-flex items-center">
          <p className="mb0 b f3">{planName()}</p>
        </div>
        <div className="gray mb3 measure flex items-center">
          <div className="pr2 mr2">{planDescription()}</div>
        </div>
      </div>
      {planDetails()}
    </div>
  );
};
