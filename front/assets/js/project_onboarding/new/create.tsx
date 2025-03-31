import * as pages from "./pages";
import * as components from "./components";
import { Routes, Route, Navigate } from "react-router-dom";
import { Steps } from "./stores/create";
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
                  path="/:integrationType/*"
                  element={<pages.Create.ChooseRepo/>}
                />
                <Route path="*" element={<Navigate to="/"/>}/>
              </Routes>
            </div>
          </div>
        </div>
      </components.ProviderProvider>
    </Steps.Provider>
  );
};
