import { Routes, Route, Navigate } from "react-router-dom";
import * as pages from "./pages";
import * as stores from "./stores";
import { useState, useContext } from "preact/hooks";
import { ProgressBar } from "../new/components/progress_bar";
import { Steps } from "./stores/create";

export const WorkflowSetupApp = () => {
  const [environmentStore] = useState(() => stores.WorkflowSetup.Environment.createEnvironmentStore());
  const { state: configState } = useContext(stores.WorkflowSetup.Config.Context);

  const steps = [
    { id: `select-type`, title: `Select project type` },
    { id: `setup-project`, title: `Setup the project` },
    { id: `select-environment`, title: `Select the environment` },
    { id: `setup-workflow`, title: `Setup workflow` },
  ];

  return (
    <Steps.Provider state={{ steps: steps }}>
      <stores.WorkflowSetup.Environment.Context.Provider value={environmentStore}>
        <ProgressBar/>
        <div
          className="pa3 pa4-m bg-lightest-blue br3"
          style="min-height: calc(100vh - 184px)"
        >
          <Routes>
            <Route
              path="/"
              element={
                configState.hasPipeline
                  ? <Navigate to="/existing_configuration" replace/>
                  : <Navigate to="/environment" replace/>
              }
            />
            <Route path="/existing_configuration" element={<pages.WorkflowSetup.ExistingConfiguration/>}/>
            <Route path="/environment" element={<pages.WorkflowSetup.Projectenvironment/>}/>
            <Route path="/starter_template" element={<pages.WorkflowSetup.StarterWorkflowTemplate/>}/>
          </Routes>
        </div>
      </stores.WorkflowSetup.Environment.Context.Provider>
    </Steps.Provider>
  );
};
