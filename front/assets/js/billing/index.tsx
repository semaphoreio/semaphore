import { render } from "preact";
import { App } from "./app";
import * as stores from "./stores";
import * as types from "./types";
import { BrowserRouter } from "react-router-dom";
import * as toolbox from "js/toolbox";
import { useSignal } from "@preact/signals";

export default function ({ config, dom }: { dom: HTMLElement, config: any }) {
  const availablePlans = config.availablePlans.map((plan: any) =>
    types.Plans.Plan.fromJSON(plan),
  );

  render(
    <BrowserRouter basename={config.baseUrl}>
      <stores.Config.Context.Provider value={{ ...config, availablePlans }}>
        <App config={config}/>
      </stores.Config.Context.Provider>
    </BrowserRouter>,
    dom,
  );
}

export function TrialOverlay({
  config,
  dom,
}: {
  dom: HTMLElement;
  config: any;
}) {
  render(
    <Trial
      ackUrl={config.acknowledgePlanChangeUrl as string}
      billingUrl={config.billingUrl as string}
    />,
    dom,
  );
}
interface TrialProps {
  ackUrl: string;
  billingUrl: string;
}
const Trial = (props: TrialProps) => {
  const disabledButton = useSignal(false);
  const confirmPlanChange = async () => {
    const url = new URL(props.ackUrl, location.origin);

    return await toolbox.APIRequest.post(url);
  };

  const onChangePlan = async () => {
    disabledButton.value = true;
    await confirmPlanChange().then(() => {
      setTimeout(() => {
        window.location.href = `${props.billingUrl}plans`;
      }, 2000);
    });
  };

  const onContinue = async () => {
    disabledButton.value = true;
    await confirmPlanChange().then(() => {
      setTimeout(() => {
        window.location.reload();
      }, 2000);
    });
  };

  return (
    <div
      className={`flex justify-center items-center ma4`}
      style="min-height: calc(80vh)"
    >
      <div className="bg-white br3 pa4 shadow-5">
        <h2 className="mb2 mh3">👋 Your Semaphore trial has ended</h2>
        <p className="f5 gray pb3 measure mh3">
          Thanks for trying Semaphore. Ready to take your CI/CD to the next
          level? Please choose your plan:
        </p>
        <div className="flex">
          <div className="mh3">
            <table className="collapse f4 pricing-table">
              <tr>
                <td className="ph3 bb b--black-10 pt3 pb2 v-top bg-green white br3 br--top">
                  <div className="f2">
                    <span className="b">Cloud</span>
                  </div>
                  <div className="f5 pr3">
                    Ideal for growing teams with frequent builds and
                    deployments.
                  </div>
                </td>
              </tr>
              <tr>
                <td className="ph3 bb b--black-10 pv2 bg-lightest-green">
                  ∞ &nbsp; <span className="b">Pay-per-use</span> billing model
                </td>
              </tr>
              <tr>
                <td className="ph3 bb b--black-10 pv2 bg-lightest-green">
                  ∞ &nbsp; <span className="b">No limits</span> on users
                </td>
              </tr>
              <tr>
                <td className="ph3 bb b--black-10 pv2 bg-lightest-green">
                  ∞ &nbsp; Unlimited concurrency
                </td>
              </tr>
              <tr>
                <td className="ph3 bb b--black-10 pv2 bg-lightest-green">
                  ☆ &nbsp; Priority support
                </td>
              </tr>
              <tr>
                <td className="ph3 pv3 bg-lightest-green br3 br--bottom">
                  <button
                    disabled={disabledButton.value}
                    className="btn btn-primary w-100"
                    onClick={() => void onChangePlan()}
                  >
                    {!disabledButton.value && `Choose Plan`}
                    {disabledButton.value && (
                      <toolbox.Asset path="images/spinner.svg"/>
                    )}
                  </button>
                </td>
              </tr>
            </table>
          </div>
          <div className="mh3">
            <table className="collapse f4 pricing-table">
              <tr>
                <td className="ph3 bb b--black-10 pt3 pb2 v-top bg-gray white br3 br--top">
                  <div className="f2">
                    <span className="b">Free</span>
                  </div>
                  <div className="f5 pr3">
                    Good for small times or individuals and occasional use.
                  </div>
                </td>
              </tr>
              <tr>
                <td className="ph3 bb b--black-10 pv2 bg-lightest-gray">
                  <span className="b">7,000</span> minutes/month
                </td>
              </tr>
              <tr>
                <td className="ph3 bb b--black-10 pv2 bg-lightest-gray">
                  <span className="b">5 active</span> users max
                </td>
              </tr>
              <tr>
                <td className="ph3 bb b--black-10 pv2 bg-lightest-gray gray">
                  ⚠ Limited concurrency
                </td>
              </tr>
              <tr>
                <td className="ph3 bb b--black-10 pv2 bg-lightest-gray gray">
                  ⚠ Limited support
                </td>
              </tr>
              <tr>
                <td className="ph3 pv3 bg-lightest-gray br3 br--bottom">
                  <button
                    disabled={disabledButton.value}
                    className="btn btn-secondary w-100"
                    onClick={() => void onContinue()}
                  >
                    {!disabledButton.value && `Continue on Free`}
                    {disabledButton.value && (
                      <toolbox.Asset path="images/spinner.svg"/>
                    )}
                  </button>
                </td>
              </tr>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
};
