import { Fragment } from "preact";
import * as toolbox from "js/toolbox";
import * as stores from "../stores";
import * as components from "../components";
import * as types from "../types";
import $ from "jquery";
import { Dispatch, StateUpdater, useContext, useEffect, useLayoutEffect, useState } from "preact/hooks";
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";
import { NavLink } from "react-router-dom";

export const OverviewPage = () => {
  const spendings = useContext(stores.Spendings.Context);
  const selectedSpending = spendings.state.selectedSpending;
  const summary = selectedSpending?.summary;
  const plan = selectedSpending?.plan;
  const currentPlan = spendings.state.currentSpending?.plan;

  return (
    <Fragment>
      <Fragment>
        <div className="flex items-center justify-between">
          <div>
            <div className="inline-flex items-center">
              <p className="mb0 b f3">
                {plan.name} plan {plan.isTrial() ? `- trial` : ``} {plan.type == types.Spendings.PlanType.Prepaid ? `- prepaid` : ``}
              </p>
            </div>
            <div className="gray mb3 measure flex items-center">
              <div className="pr2 mr2">Overview of your plan, spending, and past invoices.</div>
            </div>
          </div>
          <components.SpendingSelect/>
        </div>
        <components.PlanFlags/>
      </Fragment>
      <div className="center">
        <div className="flex mb3 b--black-075">
          <div className="bb b--black-075 w-100 mb3 br3 shadow-3 bg-white">
            <div className="flex items-center justify-between ph3 pv2 bb bw1 b--black-075 br3 br--top">
              <div>
                <div className="flex items-center">
                  <span className="material-symbols-outlined pr2">payments</span>
                  <div>
                    <span className="b">Running total </span>
                    <span className=" f6 gray">· {selectedSpending?.name} </span>
                  </div>
                </div>
              </div>
            </div>
            <div>
              {plan.type == types.Spendings.PlanType.Prepaid && <PrepaidSummary summary={summary}/>}
              {plan.type != types.Spendings.PlanType.Prepaid && <Summary plan={plan} summary={summary}/>}
            </div>
          </div>
          {plan?.details.length > 0 && <PlanOverview plan={plan}/>}
          <Payments plan={currentPlan}/>
        </div>
        <components.SpendingChart/>
        <components.InvoiceList/>
      </div>
    </Fragment>
  );
};

const PlanOverview = ({ plan }: { plan: types.Spendings.Plan }) => {
  return (
    <div className="ml3 bb b--black-075 w-100 mb3 br3 shadow-3 bg-white">
      <div className="flex items-center justify-between ph3 pv2 bb bw1 b--black-075 br3 br--top">
        <div>
          <div className="flex items-center">
            <span className="material-symbols-outlined pr2">package</span>
            <div>
              <span className="b">Plan overview </span>
              <span className=" f6 gray">· {plan?.name}</span>
            </div>
          </div>
        </div>
      </div>
      <div>
        {plan.details.map((detail, idx) => (
          <div className="bb b--black-075 hover-bg-washed-gray" key={idx}>
            <div className="ph3 pv2">
              <div className="flex items-center-ns">
                <div className="w-100">
                  <div className="flex-ns items-center">
                    <div className="w-70-ns">{detail.name}</div>
                    <div className="w-30-ns tr-ns tnum b">{detail.value}</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

enum PaymentDetailModes {
  Display,
  EditBudget,
  EditCreditCard,
}

const Payments = ({ plan }: { plan: types.Spendings.Plan }) => {
  const [mode, setMode] = useState<PaymentDetailModes>(PaymentDetailModes.Display);
  const [budget, setBudget] = useState<types.Spendings.Budget>(new types.Spendings.Budget());
  const config = useContext(stores.Config.Context);

  useEffect(() => {
    const url = new URL(config.budgetUrl, location.origin);
    fetch(url, { credentials: `same-origin` })
      .then((response) => response.json())
      .then((json) => {
        const budget = types.Spendings.Budget.fromJSON(json.budget);
        setBudget(budget);
      })
      .catch((e) => {
        e;
      });
  }, []);

  const isPrepaid = plan.type == types.Spendings.PlanType.Prepaid;
  const withPaymentDetails = plan.withPaymentDetails();

  if (!withPaymentDetails && !isPrepaid) {
    return <Fragment></Fragment>;
  }

  return (
    <div className="ml3 bb b--black-075 w-100 mb3 br3 shadow-3 bg-white">
      {isPrepaid && mode === PaymentDetailModes.Display && <PrepaidPaymentDetails budget={budget} plan={plan} setMode={setMode}/>}
      {!isPrepaid && mode === PaymentDetailModes.Display && <PaymentDetails plan={plan} budget={budget} setMode={setMode}/>}
      {mode === PaymentDetailModes.EditBudget && <EditBudget setMode={setMode} budget={budget} setBudget={setBudget}/>}
    </div>
  );
};

const PrepaidSummary = ({ summary }: { summary: types.Spendings.Summary }) => {
  return (
    <Fragment>
      <div className="bb b--black-075 hover-bg-washed-gray">
        <div className="ph3 pv2">
          <div className="flex items-center-ns">
            <div className="w-100">
              <div className="flex-ns items-center">
                <div className="w-60-ns flex-ns items-center">Pre-paid credits</div>
                <div className="w-40-ns tr-ns tnum"> {summary?.creditsStarting} </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      {summary?.discount == types.Spendings.Discount.None && <TotalSpendings summary={summary}/>}
      {summary?.discount != types.Spendings.Discount.None && <TotalSpendingsDiscounted summary={summary}/>}
      <div className="hover-bg-washed-gray">
        <div className="ph3 pv2">
          <div className="flex items-center-ns">
            <div className="w-100">
              <div className="flex-ns items-center">
                <div className="w-60-ns flex-ns items-center">
                  <span className="pr1">Credits remaining</span>
                </div>
                <div className="w-40-ns tr-ns tnum b">{summary?.creditsTotal}</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Fragment>
  );
};

const Summary = ({ plan, summary }: { summary: types.Spendings.Summary, plan: types.Spendings.Plan }) => {
  const showSummaryHelp = summary.hasSubscription() || plan.isTrial();

  const WithCreditsTooltip = () => {
    return (
      <div className="f7">
        <div className="f6 b pb1">Credits</div>
        <div className="pb1">
          <div className="flex justify-between">
            <div className="b pr2">Available:</div>
            <div>{summary?.creditsStarting}</div>
          </div>
          <div className="flex justify-between">
            <div className="b pr2">Used:</div>
            <div>{summary?.creditsUsed}</div>
          </div>
          <div className="flex justify-between">
            <div className="b pr2">Remaining:</div>
            <div>{summary?.creditsTotal}</div>
          </div>
        </div>
        {plan.areCreditsTransferable() && (
          <div className="pb1">
            Any credits remaining will
            <br/>
            be moved to the next month
          </div>
        )}
      </div>
    );
  };

  let totalBill = summary?.totalBill;

  if (plan.isTrial()) {
    totalBill = `(trial) $0.00`;
  } else if (plan.isFree()) {
    totalBill = `(free) $0.00`;
  } else if (plan.isOpenSource()) {
    totalBill = `(open source) $0.00`;
  }

  const WithoutCreditsTooltip = () => {
    return (
      <div className="f7">
        <div className="f6 b pb1">Credits</div>
        <div>
          <div>No free credits available</div>
        </div>
      </div>
    );
  };

  return (
    <Fragment>
      {summary?.discount == types.Spendings.Discount.None && <TotalSpendings summary={summary}/>}
      {summary?.discount != types.Spendings.Discount.None && <TotalSpendingsDiscounted summary={summary}/>}
      <div className="bb b--black-075 hover-bg-washed-gray">
        <div className="ph3 pv2">
          <div className="flex items-center-ns">
            <div className="w-100">
              <div className="flex-ns items-center">
                <div className="w-60-ns flex-ns items-center">
                  <span className="pr1">Credits left</span>
                  <toolbox.Tooltip
                    stickable={true}
                    anchor={
                      <span className="pointer material-symbols-outlined" style="font-size: 1em;" aria-expanded="false">
                        help
                      </span>
                    }
                    content={summary.hasStartingCredits() ? <WithCreditsTooltip/> : <WithoutCreditsTooltip/>}
                  />
                </div>
                <div className="w-40-ns tr-ns tnum">{summary?.creditsTotal}</div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div className="hover-bg-washed-gray">
        <div className="ph3 pv2">
          <div className="flex items-center-ns">
            <div className="w-100">
              <div className="flex-ns items-center">
                <div className="w-60-ns flex-ns items-center">
                  <span className="pr1">Monthly bill</span>
                  {showSummaryHelp && (
                    <toolbox.Tooltip
                      stickable={true}
                      anchor={
                        <span className="pointer material-symbols-outlined" style="font-size: 1em;" aria-expanded="false">
                          help
                        </span>
                      }
                      content={
                        <div className="f7">
                          <div className="f6 b pb1">Bill</div>
                          <div className="pb1">
                            <div className="flex justify-between">
                              <div className="b pr2">Subscription:</div>
                              <div>{summary?.subscriptionTotal}</div>
                            </div>
                            <div className="flex justify-between">
                              <div className="b pr2">Additional spending:</div>
                              <div>{summary?.usageUsed}</div>
                            </div>
                            {plan.isTrial() && (
                              <div className="flex justify-between">
                                <div className="b pr2">Trial period:</div>
                                <div>-{summary?.totalBill}</div>
                              </div>
                            )}
                            {summary?.discount != types.Spendings.Discount.None && (
                              <div className="flex justify-between">
                                <div className="b pr2">Discount:</div>
                                <div>-{summary?.discountAmount}</div>
                              </div>
                            )}
                          </div>
                        </div>
                      }
                    />
                  )}
                </div>
                <div className="w-40-ns tr-ns tnum b">{totalBill}</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Fragment>
  );
};

const EditBudget = ({
  setMode,
  budget,
  setBudget,
}: {
  setMode: Dispatch<StateUpdater<PaymentDetailModes>>;
  budget: types.Spendings.Budget;
  setBudget: (b: types.Spendings.Budget) => void;
}) => {
  const config = useContext(stores.Config.Context);
  const initialBudget = types.Spendings.Budget.fromJSON(config.budget);
  const [formError, setError] = useState(false);
  const [loading, setLoading] = useState(false);
  const url = new URL(config.budgetUrl, location.origin);

  useLayoutEffect(() => {
    setLoading(true);
    setError(false);
    fetch(url, { credentials: `same-origin` })
      .then((response) => response.json())
      .then((json) => {
        const budget = types.Spendings.Budget.fromJSON(json.budget);
        setBudget(budget);
      })
      .catch(() => {
        setError(true);
      })
      .finally(() => {
        setLoading(false);
      });
  }, []);

  const submitBudget = (e: Event) => {
    setLoading(true);
    setError(false);
    fetch(url, {
      credentials: `same-origin`,
      method: `POST`,
      body: JSON.stringify(budget),
      headers: {
        "Content-Type": `application/json`,
        "X-CSRF-Token": $(`meta[name='csrf-token']`).attr(`content`),
      },
    })
      .then((response) => response.json())
      .then((json) => {
        const budget = types.Spendings.Budget.fromJSON(json.budget);
        setBudget(budget);
        Notice.notice(`Budget saved successfully.`);
        setMode(PaymentDetailModes.Display);
      })
      .catch(() => {
        setError(true);
        Notice.error(`Saving budget failed.`);
      })
      .finally(() => {
        setLoading(false);
      });

    e.preventDefault();
  };

  const setEmail = (e: Event) => {
    const target = e.target as HTMLInputElement;
    budget.email = target.value;
    setBudget(budget);
  };

  const setLimit = (e: Event) => {
    const target = e.target as HTMLInputElement;
    budget.limit = target.value;
    setBudget(budget);
  };

  const insufficientPermissions = !config.isBillingManager;

  const insufficientPermissionsTooltip = () => {
    if (insufficientPermissions) {
      return (
        <toolbox.Tooltip
          anchor={<toolbox.Asset path="images/icn-info-15.svg" className="mr1"/>}
          content={<div className="f7">Your permissions are insufficient to edit this field.</div>}
        />
      );
    }
  };

  return (
    <form onSubmit={submitBudget}>
      <div className="flex items-center justify-between ph3 pv2 bb bw1 b--black-075 br3 br--top">
        <div className="flex items-center">
          <span className="material-symbols-outlined pr2">credit_card</span>
          <div className="b">Set budget limits</div>
        </div>
      </div>
      <div className="flex-ns flex-column">
        <div className={`bb b--black-075 hover-bg-washed-gray`}>
          <div className="ph3 pv2">
            <label className="flex items-center">
              <span className="w-50">Spending email</span>
              {insufficientPermissionsTooltip()}
              <input
                className="form-control form-control-tiny w-50 lh-solid"
                type="email"
                placeholder={initialBudget.defaultEmail}
                value={budget.email}
                onInput={setEmail}
                disabled={loading || insufficientPermissions}
              />
            </label>
          </div>
        </div>
        <div className={`bb b--black-075 ${formError ? `bg-washed-red` : `hover-bg-washed-gray`}`}>
          <div className="ph3 pv2">
            <div className="flex items-center">
              <div className="w-50 flex items-center">
                <span className="mr1">Budget limit</span>
                <toolbox.Tooltip
                  content={
                    <div className="f6">
                      Semaphore will send you an email when you spend 50%, 90% and 100% of the set budget.
                      <br/>
                      Your pipelines won’t be disabled, however, even when you go over the budget.
                    </div>
                  }
                  anchor={<toolbox.Asset className="pointer" path="images/icn-info-15.svg"/>}
                />
              </div>
              <div className="w-50 flex items-center">
                {insufficientPermissionsTooltip()}
                <input
                  className="form-control form-control-tiny lh-solid w-100"
                  type="text"
                  value={budget.limit}
                  onInput={setLimit}
                  disabled={loading || insufficientPermissions}
                />
              </div>
            </div>
          </div>
        </div>
        <div className="ph3 pv2 tl">
          <button type="submit" className="btn btn-tiny btn-primary tl mr2" disabled={insufficientPermissions}>
            Update
          </button>
          <a className="btn btn-tiny btn-secondary" onClick={() => void setMode(PaymentDetailModes.Display)}>
            Done
          </a>
        </div>
      </div>
    </form>
  );
};

const PaymentDetails = ({
  setMode,
  budget,
  plan,
}: {
  setMode: Dispatch<StateUpdater<PaymentDetailModes>>;
  budget: types.Spendings.Budget;
  plan: types.Spendings.Plan;
}) => {
  const config = useContext(stores.Config.Context);

  const UpdatePaymentMethod = () => {
    const showLink = config.isBillingManager;
    const withoutPaymentMethod = plan.noPaymentMethod();

    return (
      <Fragment>
        {showLink && (
          <a href={plan.paymentMethodUrl} target="_blank" rel="noreferrer">
            {withoutPaymentMethod && `Set ↗`}
            {!withoutPaymentMethod && `Update ↗`}
          </a>
        )}
        {!showLink && (
          <a>
            <toolbox.Tooltip
              content={<span className="f6">Contact your organization owner</span>}
              anchor={<span className="gray cursor-disabled">Update ↗</span>}
            />
          </a>
        )}
      </Fragment>
    );
  };

  return (
    <div>
      <div className="flex items-center justify-between ph3 pv2 bb bw1 b--black-075 br3 br--top">
        <div>
          <div className="flex items-center">
            <span className="material-symbols-outlined pr2">credit_card</span>
            <div className="b">Payment details</div>
          </div>
        </div>
      </div>

      <div className="bb b--black-075 hover-bg-washed-gray">
        <div className="ph3 pv2">
          <div className="flex items-center-ns">
            <div className="w-100">
              <div className="flex-ns items-center">
                {!plan.isTrial() && (
                  <Fragment>
                    <div className="w-50-ns">Charged</div>
                    <div className="w-50-ns tr-ns tnum b">monthly</div>
                  </Fragment>
                )}
                {plan.isTrial() && (
                  <Fragment>
                    <div className="w-50-ns">Trial expiring in</div>
                    <div className="w-50-ns tr-ns tnum b">{plan.expiresIn()}</div>
                  </Fragment>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
      <div className="bb b--black-075 hover-bg-washed-gray">
        <div className="ph3 pv2">
          <div className="flex items-center-ns">
            <div className="w-100">
              <div className="flex-ns items-center">
                <div className="w-70-ns">Credit card info</div>
                <div className="w-30-ns tr-ns tnum">
                  <UpdatePaymentMethod/>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div className="hover-bg-washed-gray br3 b-bottom">
        <div className="ph3 pv2">
          <div className="flex items-center-ns">
            <div className="w-100">
              <div className="flex-ns items-center">
                <div className="w-60-ns">Spending budget limits</div>
                <div className="w-40-ns flex items-center flex-row-reverse">
                  <a className="pointer underline" onClick={() => void setMode(PaymentDetailModes.EditBudget)}>
                    {!budget.hasLimit() && `Set`}
                    {budget.hasLimit() && `Update`}
                  </a>
                  {budget.hasLimit() && <span className="b pr2">{budget.limit}</span>}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

const PrepaidPaymentDetails = ({
  plan,
  setMode,
  budget,
}: {
  plan: types.Spendings.Plan;
  setMode: Dispatch<StateUpdater<PaymentDetailModes>>;
  budget: types.Spendings.Budget;
}) => {
  return (
    <div>
      <div className="flex items-center justify-between ph3 pv2 bb bw1 b--black-075 br3 br--top">
        <div>
          <div className="flex items-center">
            <span className="material-symbols-outlined pr2">credit_card</span>
            <div className="b">Payment details</div>
          </div>
        </div>
      </div>

      <div className="bb b--black-075 hover-bg-washed-gray">
        <div className="ph3 pv2">
          <div className="flex items-center-ns">
            <div className="w-100">
              <div className="flex-ns items-center">
                <div className="w-50-ns">Last precharge</div>
                <div className="w-50-ns tr-ns tnum b">{toolbox.Formatter.dateFull(plan.subscriptionStartsOn)}</div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div className="bb b--black-075 hover-bg-washed-gray">
        <div className="ph3 pv2">
          <div className="flex items-center-ns">
            <div className="w-100">
              <div className="flex-ns items-center">
                <div className="w-70-ns">Credits balance</div>
                <div className="w-30-ns tr-ns tnum">
                  <NavLink to={`/credits`}>Review</NavLink>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div className="hover-bg-washed-gray br3 b-bottom">
        <div className="ph3 pv2">
          <div className="flex items-center-ns">
            <div className="w-100">
              <div className="flex-ns items-center">
                <div className="w-60-ns">Spending budget limits</div>
                <div className="w-40-ns flex items-center flex-row-reverse">
                  <a className="pointer underline" onClick={() => void setMode(PaymentDetailModes.EditBudget)}>
                    Set...
                  </a>
                  {budget.hasLimit() && <span className="b pr2">{budget.limit}</span>}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

const TotalSpendings = ({ summary }: { summary: types.Spendings.Summary }) => {
  return (
    <Fragment>
      <div className="bb b--black-075 hover-bg-washed-gray">
        <div className="ph3 pv2">
          <div className="flex items-center-ns">
            <div className="w-100">
              <div className="flex-ns items-center">
                <div className="w-60-ns flex-ns items-center">
                  <span className="pr1">Total spending</span>
                </div>
                <div className="w-40-ns tr-ns tnum">{summary?.usageTotal}</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Fragment>
  );
};

const TotalSpendingsDiscounted = ({ summary }: { summary: types.Spendings.Summary }) => {
  return (
    <Fragment>
      <div className="bb b--black-075 hover-bg-washed-gray">
        <div className="ph3 pv2">
          <div className="flex items-center-ns">
            <div className="w-100">
              <div className="flex-ns items-center">
                <div className="w-60-ns flex-ns items-center">
                  <span className="pr1">Total spending</span>
                  {
                    <toolbox.Tooltip
                      stickable={true}
                      anchor={
                        <span className="pointer material-symbols-outlined" style="font-size: 1em;" aria-expanded="false">
                          help
                        </span>
                      }
                      content={
                        <div className="f7">
                          <div className="f6 b pb1">Discount</div>
                          <div className="pb1">
                            <div className="flex justify-between">
                              <div className="b pr2">You have a discount of:</div>
                              <div>{summary?.discount}%</div>
                            </div>
                            <div className="flex justify-between">
                              <div className="b pr2">Discounted from the original price:</div>
                              <div>-{summary?.discountAmount}</div>
                            </div>
                          </div>
                        </div>
                      }
                    />
                  }
                </div>
                <div className="w-40-ns tr-ns tnum">
                  <span className="f6 gray ml1">({summary?.discount}%) </span> {summary?.usageTotal}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Fragment>
  );
};
