import { Fragment } from "preact";
import * as types from "../types";
import * as toolbox from "js/toolbox";
import * as stores from "../stores";
import { useContext } from "preact/hooks";

export const PlanFlags = () => {
  const spendings = useContext(stores.Spendings.Context);
  const currentSpending = spendings.state.currentSpending;
  const plan = currentSpending.plan;

  return (
    <Fragment>
      <SuspensionFlag plan={plan}/>
    </Fragment>
  );
};

const SuspensionFlag = ({ plan }: { plan: types.Spendings.Plan }) => {
  if (plan.didCreditsRunOut()) {
    return <CreditsRunOut plan={plan}/>;
  }

  if (plan.noPaymentMethod()) {
    return <NoPaymentMethod plan={plan}/>;
  }

  if (plan.paymentFailed()) {
    return <PaymentFailed plan={plan}/>;
  }
};

const NoPaymentMethod = ({ plan }: { plan: types.Spendings.Plan }) => {
  return (
    <div className="flex items-center justify-between bb b--black-075 w-100-l mb3 br3 bg-red bg-pattern-wave pa3">
      <div className="white f3">Payment method not set.</div>
      <PaymentCTA plan={plan} content="Add a card to avoid interruption"/>
    </div>
  );
};

const PaymentFailed = ({ plan }: { plan: types.Spendings.Plan }) => {
  return (
    <div className="flex items-center justify-between bb b--black-075 w-100-l mb3 br3 bg-red bg-pattern-wave pa3">
      <div className="white f3">Your last payment failed.</div>
      <PaymentCTA plan={plan} content="Update your payment method"/>
    </div>
  );
};

const CreditsRunOut = ({ plan }: { plan: types.Spendings.Plan }) => {
  let content = `You ran out of credits.`;
  if (plan.isFree()) {
    content = `You used up your free credit quota.`;
  }

  return (
    <div className="flex items-center justify-between bb b--black-075 w-100-l mb3 br3 bg-red bg-pattern-wave pa3">
      <div className="white f3">{content}</div>
    </div>
  );
};

const PaymentCTA = ({
  plan,
  content,
}: {
  plan: types.Spendings.Plan;
  content: string;
}) => {
  const config = useContext(stores.Config.Context);
  const linkActive = config.isBillingManager;
  return (
    <Fragment>
      {linkActive && (
        <a href={plan.paymentMethodUrl} className="btn btn-secondary">
          {content}
        </a>
      )}
      {!linkActive && (
        <a className="btn btn-secondary">
          <toolbox.Tooltip
            content={
              <span className="f6">Contact your organization owner</span>
            }
            anchor={<span className="gray cursor-disabled">{content}</span>}
          />
        </a>
      )}
    </Fragment>
  );
};
