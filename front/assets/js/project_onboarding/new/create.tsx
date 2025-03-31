import { Fragment } from "preact";
import * as pages from "./pages";
import * as components from "./components";
import { Routes, Route, useParams } from "react-router-dom";
import { IntegrationType } from "./types/provider";
import { useContext, useEffect, useReducer, useState } from "preact/hooks";
import { Steps } from "./stores/create";
import { SelectionRegister } from "js/workflow_editor/selection_register";
import { useSteps } from "./stores/create/steps";

export const CreateApp = () => {
  return (
    <Steps.Provider state={{ steps: [] }}>
      <components.ProviderProvider>
        <components.ProgressBar/>
        <div
          className="pa3 pa4-m bg-lightest-blue br3"
          style="min-height: calc(100vh - 184px)"
        >
          <div className="pt3 pb5">
            <div className="relative mw8 center">
              <Routes>
                <Route path="/" element={<pages.Create.SelectProjectType/>}/>
                <Route
                  path="/git/*"
                  element={<pages.GenericGit.Page/>}
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
    </Steps.Provider>
  );
};
