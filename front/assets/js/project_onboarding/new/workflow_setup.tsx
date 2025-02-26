import { Fragment } from "preact";
import { Routes, Route, Navigate, useLocation } from "react-router-dom";
import * as pages from "./pages";
import * as stores from "./stores";
import { useState, useContext } from "preact/hooks";
import { ProgressBar, OnboardingStep } from "../new/components/progress_bar";

export const WorkflowSetupApp = () => {
  const [environmentStore] = useState(() => stores.WorkflowSetup.Environment.createEnvironmentStore());
  const { state: configState } = useContext(stores.WorkflowSetup.Config.Context);
  const location = useLocation();

  const getCurrentStep = (): OnboardingStep => {
    if (location.pathname === `/starter_template`) return `setup-workflow`;
    return `select-environment`;
  };

  return (
    <stores.WorkflowSetup.Environment.Context.Provider value={environmentStore}>
      <Fragment>
        <ProgressBar currentStep={getCurrentStep()}/>
        <div
          className="pa3 pa4-m bg-lightest-blue br3"
          style="min-height: calc(100vh - 184px)"
        >
          <Routes>
            <Route path="/" element={
              configState.hasPipeline
                ? <Navigate to="/existing_configuration" replace/>
                : <Navigate to="/environment" replace/>
            }/>
            <Route path="/existing_configuration" element={<pages.WorkflowSetup.ExistingConfiguration/>}/>
            <Route path="/environment" element={<pages.WorkflowSetup.Projectenvironment/>}/>
            <Route path="/starter_template" element={<pages.WorkflowSetup.StarterWorkflowTemplate/>}/>
          </Routes>
        </div>
      </Fragment>
    </stores.WorkflowSetup.Environment.Context.Provider>
  );
};
