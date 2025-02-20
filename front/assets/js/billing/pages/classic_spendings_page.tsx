import { h } from "preact";
import * as stores from "../stores";
import * as types from "../types";
import * as components from "../components";
import * as toolbox from "js/toolbox";

import { useContext } from "preact/hooks";

export const ClassicSpendingsPage = () => {
  const { state } = useContext(stores.Spendings.Context);
  return (
    <div className="w-60 center">
      <PlanInfo spending={state.selectedSpending}/>

      <components.SpendingGroup
        group={state.selectedSpending.getGroup(types.Spendings.GroupType.MachineCapacity)}
        footer={<div>Monthly price for boxes:</div>}
      />
      <components.SpendingGroup group={state.selectedSpending.getGroup(types.Spendings.GroupType.Storage)}
        footer={<div>Spending for artifacts:</div>}
      />
    </div>
  );
};

const PlanInfo = ({ spending }: { spending?: types.Spendings.Spending, }) => {
  const config = useContext(stores.Config.Context);

  if (!spending) {
    return null;
  }

  const plan = spending.plan;
  const showPaymentMethodLink = config.isBillingManager;
  const noPaymentMethod = spending.plan.noPaymentMethod();


  const planDescription = () => {
    return `Unlimited minutes.`;
  };

  const planDetails = () => {
    return (
      <div>
        <div className="inline-flex items-center">
          {(plan.requiresCreditCard() || (!plan.isTrial() && plan.isFlat()) || (plan.isTrial() && !plan.isFlat())) && showPaymentMethodLink
            && <a href={plan.paymentMethodUrl} target="_blank" rel="noreferrer">
              {noPaymentMethod && `Set credit card ↗`}
              {!noPaymentMethod && `Update credit card ↗`}
            </a>}
          {(plan.requiresCreditCard() || plan.isTrial()) && !showPaymentMethodLink && <a>
            <toolbox.Tooltip
              content={<span className="f6">
                Contact your organization owner
              </span>}
              anchor={<span className="gray cursor-disabled">Update credit card ↗</span>}
            />
          </a>}
          {(plan.isTrial() && plan.isFlat())
            && <a>
              <toolbox.Tooltip
                content={<span className="f6">
                  Please contact support@semaphoreci.com in order to add the credit card
                </span>}
                anchor={<span className="gray cursor-disabled">Update credit card ↗</span>}
              />
            </a>}
        </div>
      </div>
    );

  };


  return (
    <div className="flex items-center justify-between">
      <div>
        <div className="inline-flex items-center">
          <p className="mb0 b f3">{plan.name}</p>
        </div>
        <div className="gray mb3 measure flex items-center">
          <div className="pr2 mr2">{planDescription()}</div>
        </div>
      </div>
      {planDetails()}
    </div>
  );
};
