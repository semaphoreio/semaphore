import { Fragment } from "preact";
import * as pages from "./pages";
import * as components from "./components";
import { Routes, Route, useLocation } from "react-router-dom";
import { OnboardingStep } from "./components/progress_bar";

export const CreateApp = () => {
  const location = useLocation();

  // TODO: MK/REFACTOR
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
          <div className="pt3 pb5">
            <div className="relative mw8 center">
              <Routes>
                <Route path="/" element={<pages.Create.SelectProjectType/>}/>
                <Route
                  path="/git"
                  element={<pages.Create.GenericGit/>}
                />
                <Route
                  path="/:integrationType"
                  element={<pages.Create.ChooseRepo/>}
                />
              </Routes>
            </div>
          </div>
        </div>
      </components.ProviderProvider>
    </Fragment>
  );
};
