import { Fragment } from "preact";
import * as toolbox from "js/toolbox";
import { useContext, useEffect, useState } from "preact/hooks";
import { Plans } from "../types";
import * as stores from "../stores";
import { useSignal } from "@preact/signals";
import { useNavigate } from "react-router-dom";

export const PlansPage = () => {
  const config = useContext(stores.Config.Context);
  const plans = config.availablePlans;

  if (!plans || plans.length === 0) return null;

  return (
    <Fragment>
      <div className="mb3">
        <p className="mb0 b f3">Change Plan</p>
        <div className="gray measure">
          Select a plan that works best for you and your team.
        </div>
      </div>

      {plans.map((plan) => (
        <PlanCard key={plan.type} plan={plan} />
      ))}
    </Fragment>
  );
};

const PlanCard = ({ plan }: { plan: Plans.Plan }) => {
  const config = useContext(stores.Config.Context);
  const isCurrent = config.currentPlanType === plan.type;
  const [confirming, setConfirming] = useState(false);

  if (confirming) {
    return <PlanConfirmation plan={plan} onCancel={() => setConfirming(false)} />;
  }

  return (
    <div className="bb b--black-075 br3 shadow-3 bg-white mb3">
      <div className="flex items-center justify-between ph3 pv3">
        <div>
          <div className="f3 b">{plan.name}</div>
          <div className="f5 gray mt1">
            {plan.description}
            {` `}
            <a href={config.pricingUrl} target="_blank" rel="noreferrer" className="link">
              See pricing details
            </a>
          </div>
        </div>
        <div>
          {isCurrent && (
            <span className="f6 ph3 pv2 br3 bg-green white b">Current plan</span>
          )}
          {!isCurrent && (
            <button
              className="btn btn-primary"
              onClick={() => setConfirming(true)}
            >
              Switch to {plan.name}
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

interface PlanConfirmationProps {
  plan: Plans.Plan;
  onCancel: () => void;
}

const PlanConfirmation = (props: PlanConfirmationProps) => {
  const plan = props.plan;
  const config = useContext(stores.Config.Context);
  const navigate = useNavigate();
  const errors = useSignal<string | null>(null);
  const isLoading = useSignal(false);
  const [allowed, setAllowed] = useState(false);

  const onPlanConfirmed = async () => {
    errors.value = null;
    isLoading.value = true;
    const url = new URL(config.upgradeUrl, location.origin);
    url.searchParams.append(`plan_type`, plan.type);
    interface Response {
      spending_id: string;
      payment_method_url: string;
      errors: string[];
    }
    const { data, error } = await toolbox.APIRequest.post<Response>(url, {
      plan_type: plan.type,
    });

    if (error) {
      isLoading.value = false;
      errors.value = error;
    } else {
      if (data.payment_method_url !== ``) {
        window.location.href = data.payment_method_url;
      } else {
        setTimeout(() => {
          navigate(`/overview?spending_id=${data.spending_id}`);
        }, 2000);
      }
    }
  };

  return (
    <div className="bb b--black-075 br3 shadow-3 bg-white mb3">
      <div className="ph3 pv3">
        <div className="f4 mb3">
          You are about to switch to <span className="b">{plan.name}</span>.
        </div>
        <div className="f5 gray mb3">{plan.description}</div>

        <VerifyPlanUpgrade setAllowed={setAllowed} planType={plan.type} />

        {isLoading.value && (
          <div className="flex pv3">
            <toolbox.Asset path="images/spinner.svg" className="spinner" />
          </div>
        )}
        {errors.value && (
          <div className="f6 red pv2">
            <ul className="list pl0">{errors.value}</ul>
          </div>
        )}

        <div className="flex mt3" style={{ gap: `8px` }}>
          <button
            className="btn btn-primary"
            disabled={!allowed || isLoading.value}
            onClick={() => void onPlanConfirmed()}
          >
            Confirm
          </button>
          <button
            className="btn btn-secondary"
            onClick={() => props.onCancel()}
          >
            Cancel
          </button>
        </div>
      </div>
    </div>
  );
};

interface VerifyPlanUpgradeProps {
  planType: string;
  setAllowed: (allowed: boolean) => void;
}

const VerifyPlanUpgrade = (props: VerifyPlanUpgradeProps) => {
  const config = useContext(stores.Config.Context);
  const isLoading = useSignal(false);
  const [errs, setErrors] = useState<Map<string, string[]>>(new Map());

  const checkPlanUpgrade = async (planType: string) => {
    interface Response {
      allowed: boolean;
      errors: Map<string, string[]>;
    }
    isLoading.value = true;
    const url = new URL(config.canUpgradeUrl, location.origin);
    url.searchParams.append(`plan_type`, planType);

    const { data, error } = await toolbox.APIRequest.get<Response>(
      url,
      { plan_type: planType },
      {},
      (data) => {
        const myErrors = new Map<string, string[]>();
        for (const key in data.errors) {
          myErrors.set(key, data.errors[key] as string[]);
        }
        return { allowed: data.allowed, errors: myErrors };
      }
    );
    isLoading.value = false;
    if (error) {
      setErrors(data.errors);
    } else {
      props.setAllowed(data.allowed);
    }
  };

  useEffect(() => {
    void checkPlanUpgrade(props.planType);
  }, []);

  const errorsEl: preact.VNode[] = [];
  for (const [key, value] of errs.entries()) {
    for (const err of value) {
      switch (key) {
        case `users`:
          errorsEl.push(
            <li key={err}>
              {err}{` `}
              <a href={config.peoplePageUrl} target="_blank" className="link" rel="noreferrer">
                Manage people
              </a>
            </li>
          );
          break;
        case `agents`:
          errorsEl.push(
            <li key={err}>
              {err}{` `}
              <a href={config.agentsPageUrl} target="_blank" className="link" rel="noreferrer">
                Manage agents
              </a>
            </li>
          );
          break;
        default:
          errorsEl.push(<li key={err}>{err}</li>);
          break;
      }
    }
  }

  return (
    <Fragment>
      {isLoading.value && (
        <div className="flex pv2">
          <toolbox.Asset path="images/spinner.svg" className="spinner" />
        </div>
      )}
      {errorsEl.length > 0 && (
        <div className="f6 red pv2">
          <ul className="list pl0">{errorsEl}</ul>
        </div>
      )}
    </Fragment>
  );
};
