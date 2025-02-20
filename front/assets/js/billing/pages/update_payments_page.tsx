import { h } from "preact";
import * as stores from "../stores";
import * as toolbox from "js/toolbox";
import { useContext } from "preact/hooks";

export const UpdatePaymentsPage = () => {
  const config = useContext(stores.Config.Context);
  const isManager = config.isBillingManager;
  const spendings = useContext(stores.Spendings.Context);
  const currentSpending = spendings.state?.currentSpending;
  const plan = currentSpending?.plan;

  return (
    <div className="mw6 center pa4 br3 bg-white bb b--black-075 shadow-3">
      <div className="flex items-end justify-between mb4">
        <div>
          <h1 className="f1 mb2">No active subscription</h1>
          <p className="mb1">
            It looks like your subscription has ended at{` `}
            <b>{toolbox.Formatter.dateFull(plan.subscriptionEndsOn)}</b>.
          </p>
          <p className="mb1">
            Please update your payment method to reactivate your subscription.
          </p>
        </div>
      </div>
      <div className="tr">
        <div>
          {!isManager && (
            <toolbox.Tooltip
              content={
                <span className="f6">
                  You need to be a billing manager to update your payment
                  method.
                </span>
              }
              anchor={
                <a
                  className="db btn btn-secondary gray cursor-disabled"
                  disabled
                >
                  Update payment method
                </a>
              }
            />
          )}
          {isManager && (
            <a className="db btn btn-primary" href={plan.paymentMethodUrl}>
              Update payment method
            </a>
          )}
        </div>
      </div>
    </div>
  );
};
