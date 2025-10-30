import { Fragment, VNode } from "preact";
import * as toolbox from "js/toolbox";
import { useContext, useEffect, useState } from "preact/hooks";
import { Plans } from "../types";
import * as stores from "../stores";
import { useSignal } from "@preact/signals";
import { useNavigate } from "react-router-dom";

export const PlansPage = () => {
  const config = useContext(stores.Config.Context);
  const plans = config.availablePlans;
  const [selectedPlan, setSelectedPlan] = useState<Plans.Plan | null>();

  const onPlanSelected = (plan: Plans.Plan) => {
    setSelectedPlan(plan);
  };

  return (
    <Fragment>
      {!selectedPlan && (
        <Fragment>
          <div className="flex items-center">
            <div>
              <div className="inline-flex items-center">
                <p className="mb0 b f3">Choose a plan</p>
              </div>
              <div className="gray mb3 measure flex items-center">
                <div className="pr2 mr2">
                  See what works best for you and your team
                </div>
              </div>
            </div>
            <div className="tr">
              <div className="gray flex items-center flex-row-reverse"></div>
            </div>
          </div>
          <div className="bb b--black-075 w-100 mb3 br3 shadow-3 bg-white">
            <div className="flex items-center justify-between ph3 pv2 bb bw1 b--black-075 br3 br--top ">
              <div>
                <div className="flex items-center">
                  <span className="material-symbols-outlined pr2">package</span>
                  <div className="b">My billing plan </div>
                </div>
              </div>
            </div>
            <div className="ph3 pv2">
              <PlanSelection plans={plans} setSelectedPlan={onPlanSelected}/>
              <ContactPlanSelection/>
            </div>
          </div>
        </Fragment>
      )}
      {selectedPlan && (
        <PlanConfirmation
          plan={selectedPlan}
          onCancel={() => onPlanSelected(null)}
        />
      )}
    </Fragment>
  );
};

const ContactPlanSelection = () => {
  const config = useContext(stores.Config.Context);
  return (
    <div className="flex mt5 bt b--black-10 pt4">
      <div className="w-50 pr3">
        <div className="f2 mb3">
          <span className="b">Need more options?</span>
        </div>
        <p className="f5 gray">
          Building frequently? Cut costs with the{` `}
          <span className="b">Enterprise plan</span>. It offers advanced control,
          governance, and support SLAs, all in one annual package.
        </p>
        <p className="f5 gray pb3">
          Our special plan for <span className="b">Open Source</span> projects
          offers unlimited free minutes and user seats for all public projects.
        </p>

        <toolbox.Asset path="images/ill-girl-showing-continue.svg"/>
      </div>
      <div className="w-50 flex">
        <div className="w-50 mr3">
          <table className="dn db-m collapse f4">
            <tbody>
              <tr>
                <td className="ph3 bb b--black-10 pt3 pb2 v-top bg-purple white br3 br--top">
                  <div className="f2">
                    <span className="b">Enterprise</span>
                  </div>
                  <div className="f5 pr3">
                    For peak performance teams that build frequently.
                  </div>
                </td>
              </tr>
              <tr>
                <td className="ph3 bb b--black-10 pv2 bg-lightest-purple">
                  ☆ &nbsp; Usage discount
                </td>
              </tr>
              <tr>
                <td className="ph3 bb b--black-10 pv2 bg-lightest-purple">
                  ☆ &nbsp; Annual billing
                </td>
              </tr>
              <tr>
                <td className="ph3 bb b--black-10 pv2 bg-lightest-purple">
                  ☆ &nbsp; Advanced security
                </td>
              </tr>
              <tr>
                <td className="ph3 bb b--black-10 pv2 bg-lightest-purple">
                  ☆ &nbsp; Premium support
                </td>
              </tr>
              <tr>
                <td className="ph3 pv3 bg-lightest-purple br3 br--bottom">
                  <a
                    href={config.contactSupportUrl}
                    className="btn btn-secondary w-100"
                  >
                    Contact us
                  </a>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <div className="w-50">
          <table className="dn db-m collapse f4">
            <tbody>
              <tr>
                <td className="ph3 bb b--black-10 pt3 pb2 v-top bg-purple white br3 br--top">
                  <div className="f2">
                    <span className="b">Open Source</span>
                  </div>
                  <div className="f5 pr3">
                    Free unlimited machine time for public projects.
                  </div>
                </td>
              </tr>
              <tr>
                <td className="ph3 bb b--black-10 pv2 bg-lightest-purple">
                  ∞ Unlimited minutes
                </td>
              </tr>
              <tr>
                <td className="ph3 bb b--black-10 pv2 bg-lightest-purple">
                  ∞ Unlimited users
                </td>
              </tr>
              <tr>
                <td className="ph3 bb b--black-10 pv2 bg-lightest-purple gray">
                  ⚠ Limited concurrency
                </td>
              </tr>
              <tr>
                <td className="ph3 bb b--black-10 pv2 bg-lightest-purple gray">
                  ⚠ Public projects only
                </td>
              </tr>
              <tr>
                <td className="ph3 pv3 bg-lightest-purple br3 br--bottom">
                  <a
                    href={config.contactSupportUrl}
                    className="btn btn-secondary w-100"
                  >
                    Contact us
                  </a>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

const PlanSelection = (props: PlanSelectionProps) => {
  const config = useContext(stores.Config.Context);

  const isCurrent = (plan: Plans.Plan) => {
    return config.currentPlanType === plan.type;
  };

  return (
    <Fragment>
      <div className="flex items-stretch">
        <div className="w-25 pt3 pb2 bb b--black-10">
          <toolbox.Asset path="images/ill-couple-heads.svg"/>
        </div>
        {props.plans.map((plan, idx) => (
          <PlanDescription
            key={idx}
            plan={plan}
            className={`w-25 ${isCurrent(plan) ? `bg-lightest-green` : ``}`}
            descriptionClassName={`${isCurrent(plan) ? `green` : ``}`}
          />
        ))}
      </div>

      <div className="flex items-stretch f3">
        <PlanFeature
          name="Parallelism"
          description="The number of jobs that can run at the same time."
          className="w-25"
        />
        {props.plans.map((plan, idx) => (
          <PlanParallelism
            key={idx}
            plan={plan}
            className={`w-25 ${isCurrent(plan) ? `bg-lightest-green` : ``}`}
          />
        ))}
      </div>

      <div className="flex items-stretch f3">
        <PlanFeature
          name="Maximum users"
          description="Maximum number of users you can have in your organization."
          className="w-25"
        />
        {props.plans.map((plan, idx) => (
          <PlanMaxUsers
            key={idx}
            plan={plan}
            className={`w-25 ${isCurrent(plan) ? `bg-lightest-green` : ``}`}
          />
        ))}
      </div>

      <div className="flex items-stretch f3">
        <PlanFeature
          name="Self-hosted agents"
          description="Number of active self-hosted agents you can have at the same time."
          className="w-25"
        />
        {props.plans.map((plan, idx) => (
          <PlanSelfHostedAgents
            key={idx}
            plan={plan}
            className={`w-25 ${isCurrent(plan) ? `bg-lightest-green` : ``}`}
          />
        ))}
      </div>

      <div className="flex items-stretch f3">
        <PlanFeature
          name="Seat cost"
          description="Seat cost charged per active user in a month."
          className="w-25"
        />
        {props.plans.map((plan, idx) => (
          <PlanSeatCost
            key={idx}
            plan={plan}
            className={`w-25 ${isCurrent(plan) ? `bg-lightest-green` : ``}`}
          />
        ))}
      </div>

      <div className="flex items-stretch f3">
        <PlanFeature
          name="Cloud machines"
          description="Access to the cloud machine resources."
          className="w-25"
        />
        {props.plans.map((plan, idx) => (
          <PlanCloudMachines
            key={idx}
            plan={plan}
            className={`w-25 ${isCurrent(plan) ? `bg-lightest-green` : ``}`}
          />
        ))}
      </div>
      <div className="flex items-stretch f3">
        <PlanFeature
          name="Large resource types"
          description="Access to larger cloud resource types. Free plan has access only to the 2vCPU machines."
          className="w-25"
        />

        {props.plans.map((plan, idx) => (
          <PlanLargeResourceTypes
            key={idx}
            plan={plan}
            className={`w-25 ${isCurrent(plan) ? `bg-lightest-green` : ``}`}
          />
        ))}
      </div>
      <div className="flex items-stretch f3">
        <PlanFeature
          name="Priority support"
          description="Priority tech. and account email support."
          className="w-25"
        />
        {props.plans.map((plan, idx) => (
          <PlanPrioritySupport
            key={idx}
            plan={plan}
            className={`w-25 ${isCurrent(plan) ? `bg-lightest-green` : ``}`}
          />
        ))}
      </div>
      <div className="flex items-start f3">
        <div className="w-25"></div>
        {props.plans.map((plan, idx) => (
          <SelectPlan
            key={idx}
            plan={plan}
            setSelectedPlan={props.setSelectedPlan}
            className={`w-25 ${isCurrent(plan) ? `bg-lightest-green` : ``}`}
          />
        ))}
      </div>

      <div className="flex items-start f3">
        <div className="w-25"></div>
        {props.plans.map((plan, idx) => (
          <div
            className={`w-25 pa3 f5 ${
              isCurrent(plan) ? `bg-green white f5` : ``
            } br3 br--bottom`}
            key={idx}
          >
            {isCurrent(plan) && <div>✓ Your current plan</div>}
          </div>
        ))}
      </div>
    </Fragment>
  );
};

interface PlanConfirmationProps {
  plan: Plans.Plan;
  onCancel: () => void;
}

const PlanConfirmation = (props: PlanConfirmationProps) => {
  const plan = props.plan;
  const config = useContext(stores.Config.Context);
  const [allowed, setAllowed] = useState(false);
  const navigate = useNavigate();
  const errors = useSignal<string | null>(null);
  const isLoading = useSignal(false);

  const onPlanConfirmed = async (planType: string) => {
    errors.value = null;
    isLoading.value = true;
    const url = new URL(config.upgradeUrl, location.origin);
    url.searchParams.append(`plan_type`, planType);
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
    <Fragment>
      <div className="flex items-center mb3">
        <div>
          <div className="inline-flex items-center">
            <p className="mb0 b f3">Confirm your plan</p>
          </div>
        </div>
      </div>
      <div className="bb b--black-075 w-100 mb3 br3 shadow-3 bg-white ph3 pv2">
        <div className="flex justify-center f3">
          <div className="pa3 w-50">
            <div className="mb3 flex items-center">
              <div className="pr2 mr2">
                You are about to switch to the{` `}
                <span className="b">{plan.name}</span> plan.
              </div>
            </div>

            <div className="flex items-stretch f3">
              <PlanFeature
                name="Parallelism"
                description="The number of jobs that can run at the same time."
                className="w-50"
              />
              <PlanParallelism plan={plan} className={`w-50`}/>
            </div>
            <div className="flex items-stretch f3">
              <PlanFeature
                name="Maximum users"
                description="Maximum number of users you can have in your organization."
                className="w-50"
              />
              <PlanMaxUsers plan={plan} className={`w-50`}/>
            </div>
            <div className="flex items-stretch f3">
              <PlanFeature
                name="Self-hosted agents"
                description="Number of active self-hosted agents you can have at the same time."
                className="w-50"
              />
              <PlanSelfHostedAgents plan={plan} className={`w-50`}/>
            </div>
            <div className="flex items-stretch f3">
              <PlanFeature
                name="Seat cost"
                description="Seat cost charged per active user in a month."
                className="w-50"
              />
              <PlanSeatCost plan={plan} className={`w-50`}/>
            </div>
            <div className="flex items-stretch f3">
              <PlanFeature
                name="Cloud machines"
                description="Access to the cloud machine resources."
                className="w-50"
              />
              <PlanCloudMachines plan={plan} className={`w-50`}/>
            </div>
            <div className="flex items-stretch f3">
              <PlanFeature
                name="Large resource types"
                description="Access to larger cloud resource types. Free plan has access only to the 2vCPU machines."
                className="w-50"
              />
              <PlanLargeResourceTypes plan={plan} className={`w-50`}/>
            </div>
            <div className="flex items-stretch f3">
              <PlanFeature
                name="Priority support"
                description="Priority tech. and account email support."
                className="w-50"
              />
              <PlanPrioritySupport plan={plan} className={`w-50`}/>
            </div>
          </div>
        </div>
        {isLoading.value && (
          <div className="flex justify-center f3">
            <toolbox.Asset path="images/spinner.svg" className="spinner"/>
          </div>
        )}
        {errors.value && (
          <div className="flex justify-center f3">
            <div className="flex items-center w-50 ph3">
              <div className="f6 red w-100">
                <ul className="list pl0">{errors.value}</ul>
              </div>
            </div>
          </div>
        )}
        <VerfiyPlanUpgrade setAllowed={setAllowed} planType={plan.type}/>
        <div className="flex justify-center f3">
          <div className="w-50 flex">
            <div className="w-50 pt3 pb3 br3 br--bottom ph3">
              <button
                className="btn w-100 btn-primary"
                disabled={!allowed || isLoading.value}
                onClick={() => void onPlanConfirmed(plan.type)}
              >
                Confirm
              </button>
            </div>
            <div className="w-50 pt3 pb3 br3 br--bottom ph3">
              <button
                className="btn w-100 btn-secondary"
                onClick={() => props.onCancel()}
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      </div>
    </Fragment>
  );
};

interface PlanSelectionProps {
  plans: Plans.Plan[];
  setSelectedPlan: (plan: Plans.Plan) => void;
}

interface PlanFeatureProps {
  name: string;
  description: string;
  className?: string;
}
const PlanFeature = (props: PlanFeatureProps) => {
  const { name, description } = props;
  return (
    <div className={`pv1 bb b--black-10 f4 gray ${props.className}`}>
      <span className="pointer">
        <toolbox.Tooltip
          anchor={
            <span>
              {name} <span className="mid-gray">•</span>
            </span>
          }
          content={<>{description}</>}
          placement="top"
        />
      </span>
    </div>
  );
};

interface VerifyPlanUpgradeProps {
  planType: string;
  setAllowed: (allowed: boolean) => void;
}

const VerfiyPlanUpgrade = (props: VerifyPlanUpgradeProps) => {
  const config = useContext(stores.Config.Context);
  const isLoading = useSignal(false);
  const [errors, setErrors] = useState<Map<string, string[]>>(new Map());
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
      {
        plan_type: planType,
      },
      {},
      (data) => {
        const myErrors = new Map<string, string[]>();
        for (const key in data.errors) {
          myErrors.set(key, data.errors[key] as string[]);
        }

        return {
          allowed: data.allowed,
          errors: myErrors,
        };
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

  const displayErrors = () => {
    const errorsEl: VNode[] = [];

    for (const [key, value] of errors.entries()) {
      for (const error of value) {
        switch (key) {
          case `users`:
            errorsEl.push(
              <li>
                {error}
                <span className="mh1">
                  Visit the
                  <a
                    href={config.peoplePageUrl}
                    target="_blank"
                    className="mh1 link"
                    rel="noreferrer"
                  >
                    people page
                  </a>
                  page and remove some of the users.
                </span>
              </li>
            );
            break;

          case `agents`:
            errorsEl.push(
              <li>
                {error}
                <span className="mh1">
                  Visit the
                  <a
                    href={config.agentsPageUrl}
                    target="_blank"
                    className="mh1 link"
                    rel="noreferrer"
                  >
                    self-hosted agents
                  </a>
                  page and remove some of the agents.
                </span>
              </li>
            );
            break;

          default:
            errorsEl.push(<li>{error}</li>);
            break;
        }
      }
    }

    return (
      <Fragment>
        {errorsEl.length > 0 && (
          <div className="flex items-center w-50 ph3">
            <div className="f6 red w-100">
              <ul className="list pl0">{errorsEl.map((error) => error)}</ul>
            </div>
          </div>
        )}
      </Fragment>
    );
  };

  return (
    <div className="flex justify-center f3">
      {isLoading.value && (
        <toolbox.Asset path="images/spinner.svg" className="spinner"/>
      )}
      {!isLoading.value && displayErrors()}
    </div>
  );
};

const PlanDescription = (props: {
  plan: Plans.Plan;
  className?: string;
  descriptionClassName?: string;
}) => {
  const plan = props.plan;
  return (
    <div
      className={`ph3 pt3 pb2 bb b--black-10 br3 br--top ${props.className}`}
    >
      <div className="f2">
        <span className="b">{plan.name}</span>
      </div>
      <div className={`f5 pr3 ${props.descriptionClassName}`}>
        {plan.description}
      </div>
    </div>
  );
};

const PlanParallelism = (props: { plan: Plans.Plan, className?: string, }) => {
  const plan = props.plan;
  const parallelism = plan.features.parallelism;
  return (
    <div className={`pv1 bb b--black-10 ph3 ${props.className}`}>
      <div className="flex items-center">
        {Number.isFinite(parallelism) && (
          <>
            {parallelism}
            <span className="f5 ml1 gray">x jobs</span>
          </>
        )}
        {!Number.isFinite(parallelism) && `∞ Unlimited`}
      </div>
    </div>
  );
};

const PlanMaxUsers = (props: { plan: Plans.Plan, className?: string, }) => {
  const plan = props.plan;
  const maxUsers = plan.features.maxUsers;
  return (
    <div className={`pv1 bb b--black-10 ph3 ${props.className}`}>
      <div className="flex items-center">
        {Number.isFinite(maxUsers) && (
          <>
            {maxUsers}
            <span className="f5 ml1 gray">x users</span>
          </>
        )}
        {!Number.isFinite(maxUsers) && `∞ Unlimited`}
      </div>
    </div>
  );
};

const PlanSelfHostedAgents = (props: {
  plan: Plans.Plan;
  className?: string;
}) => {
  const plan = props.plan;
  const selfHostedAgentsCount = (selfHostedAgents: number) => {
    switch (selfHostedAgents) {
      case 0:
        return <span className="gray">✗</span>;
      case Number.POSITIVE_INFINITY:
        return `∞ Unlimited`;
      default:
        return (
          <div className="flex items-center">
            {selfHostedAgents}
            <span className="f5 ml1 gray">x agents</span>
          </div>
        );
    }
  };

  return (
    <div className={`pv1 bb b--black-10 ph3 ${props.className}`}>
      <div className="flex items-center">
        {selfHostedAgentsCount(plan.features.maxSelfHostedAgents)}
      </div>
    </div>
  );
};

const PlanSeatCost = (props: { plan: Plans.Plan, className?: string, }) => {
  const plan = props.plan;
  return (
    <div className={`pv1 bb b--black-10 ph3 ${props.className}`}>
      {toolbox.Formatter.toMoney(plan.features.seatCost)}
    </div>
  );
};

const PlanCloudMachines = (props: { plan: Plans.Plan, className?: string, }) => {
  const plan = props.plan;
  const cloudMachinesCount = (cloudMachines: number) => {
    switch (cloudMachines) {
      case 0:
        return <span className="gray">✗</span>;
      case Number.POSITIVE_INFINITY:
        return <div className="green">✓</div>;
      default:
        return (
          <div className="flex items-center">
            {toolbox.Formatter.decimalThousands(cloudMachines)}
            <span className="f5 ml1 gray">x min</span>
          </div>
        );
    }
  };

  return (
    <div className={`pv1 bb b--black-10 ph3 ${props.className}`}>
      {cloudMachinesCount(plan.features.cloudMinutes)}
    </div>
  );
};

const PlanLargeResourceTypes = (props: {
  plan: Plans.Plan;
  className?: string;
}) => {
  const plan = props.plan;
  const largeResourceTypes = plan.features.largeResourceTypes;
  return (
    <div className={`pv1 bb b--black-10 ph3 ${props.className}`}>
      {largeResourceTypes ? (
        <div className="green">✓</div>
      ) : (
        <div className="gray">✗</div>
      )}
    </div>
  );
};

const PlanPrioritySupport = (props: {
  plan: Plans.Plan;
  className?: string;
}) => {
  const plan = props.plan;
  return (
    <div className={`pv1 bb b--black-10 ph3 ${props.className}`}>
      {plan.features.prioritySupport ? (
        <div className="green">✓</div>
      ) : (
        <div className="gray">✗</div>
      )}
    </div>
  );
};

interface SelectPlanProps {
  plan: Plans.Plan;
  setSelectedPlan: (plan: Plans.Plan) => void;
  className?: string;
}

const SelectPlan = (props: SelectPlanProps) => {
  const config = useContext(stores.Config.Context);
  const plan = props.plan;
  const isCurrent = config.currentPlanType === plan.type;

  const onSelectPlan = (plan: Plans.Plan) => {
    if (!plan.contactRequired) {
      props.setSelectedPlan(plan);
    }
  };

  const showContactUs =
    !isCurrent &&
    config.currentPlanType != `free` &&
    plan.type === `startup_hybrid`;

  return (
    <div className={`pt3 pb3 ph3 ${props.className}`}>
      {!showContactUs && (
        <button
          className={`btn w-100 btn-primary`}
          onClick={() => onSelectPlan(plan)}
          disabled={isCurrent}
        >
          Switch
        </button>
      )}
      {showContactUs && (
        <a
          className={`btn w-100 btn-secondary`}
          href={config.contactSupportUrl}
        >
          Contact us
        </a>
      )}
    </div>
  );
};
