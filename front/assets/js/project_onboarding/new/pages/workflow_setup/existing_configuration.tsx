/* eslint-disable quotes */

import * as stores from "../../stores";
import * as components from "../../components";
import { useContext, useLayoutEffect } from "preact/hooks";
import { useNavigate } from "react-router-dom";

import { useSteps } from "../../stores/create/steps";
import { handleSkipOnboarding } from "../../utils/skip_onboarding";

export const ExistingConfiguration = () => {
  const { state: configState } = useContext(stores.WorkflowSetup.Config.Context);
  const navigate = useNavigate();
  const { dispatch } = useSteps();

  useLayoutEffect(() => {
    dispatch([`SET_CURRENT`, `setup-workflow`]);
  }, []);

  const onHandleUseExisting = (e: Event) => {
    e.preventDefault();
    void handleSkipOnboarding({
      skipOnboardingUrl: configState.skipOnboardingUrl,
      csrfToken: configState.csrfToken,
      projectUrl: configState.projectUrl,
    });
  };

  const onHandleCreateNew = (e: Event) => {
    e.preventDefault();
    navigate(`/environment`);
  };

  return (
    <div className="pt3 pb5">
      <div className="relative mw8 center">
        <div className="flex-l">
          <components.InfoPanel
            svgPath="images/ill-girl-looking-down.svg"
            title="Connect repository"
            subtitle="Configure repository access and integration settings."
            additionalInfo="Deploy keys enable read-only repository access. Webhooks trigger automated builds on code changes."
          />

          {/* LEFT SIDE */}
          <div className="flex-auto w-two-thirds">
            <div className="bg-washed-yellow pa3 mt3 shadow-1 br2">
              <p className="mb0 f4 fw6">Well done, we found the existing configuration!</p>
              <p className="mb0 pt2 bt b--black-10">
                Looks like you already have <code className="f6 ba ph1 br2">.yml</code> configuration in this project.
              </p>
              <p className="mb0">What would you like to do?</p>
              <ul className="mb3"></ul>
              <div>
                <div className="mv3">
                  <a href="#" onClick={onHandleUseExisting} className="db f4 mb1">
                    I will use the existing configuration
                  </a>
                  <p className="mb0 measure">
                    We&apos;ll take you directly to the project, but don&apos;t forget to push to repository to see your
                    work running there.
                  </p>
                </div>

                <div className="f6 w2 h2 flex items-center justify-center ba br-100">or</div>

                <div className="mv3">
                  <a href="#" onClick={onHandleCreateNew} className="db f4 mb1">
                    I want to configure this project from scratch
                  </a>
                  <p className="mb0 measure">We&apos;ll take you through the usual setup process</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
