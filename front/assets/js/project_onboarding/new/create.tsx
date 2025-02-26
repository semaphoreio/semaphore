import { Fragment } from "preact";
import * as pages from "./pages";
import * as components from "./components";
import { Routes, Route, Navigate, useLocation } from "react-router-dom";
import { IntegrationType } from "./types/provider";
import { OnboardingStep } from "./components/progress_bar";

export const CreateApp = () => {
  const location = useLocation();

  const getCurrentStep = (): OnboardingStep => {
    if (location.pathname === `/`) return `select-type`;
    if (location.pathname === `/github_oauth_token`) return `setup-project`;
    if (location.pathname === `/bitbucket`) return `setup-project`;
    if (location.pathname === `/github_app`) return `setup-project`;
    if (location.pathname === `/gitlab`) return `setup-project`;
  };

  return (
    <Fragment>
      <components.ProviderProvider>
        <components.ProgressBar currentStep={getCurrentStep()}/>
        <div
          className="pa3 pa4-m bg-lightest-blue br3"
          style="min-height: calc(100vh - 184px)"
        >
          {/* <div className="w-100-l ph3"> */}
          <div className="pt3 pb5">
            {/* this is in outer div thingy w-100-l ph3 */}
            <div className="relative mw8 center">
              <Routes>
                <Route path="/" element={<pages.Create.SelectProjectType/>}/>
                {Object.values(IntegrationType).map(integrationType => (
                  <Route
                    key={integrationType}
                    path={integrationType}
                    element={<pages.Create.ChooseRepo/>}
                  />
                ))}
                <Route path="*" element={<Navigate to="/"/>}/>
              </Routes>
            </div>
            {/* </div> */}
          </div>
        </div>
      </components.ProviderProvider>
    </Fragment>
  );
};
