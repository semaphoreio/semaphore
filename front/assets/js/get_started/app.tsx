
import { useContext, useReducer } from "preact/hooks";
import * as stores from "./stores";
import * as types from "./types";
import * as pages from "./pages";
import { Routes, Route } from "react-router-dom";

export const App = () => {
  const config = useContext(stores.Config.Context);

  const learn = types.Onboarding.Learn.fromJSON(config.learn);

  const [onboarding, dispatchOnboarding] = useReducer(
    stores.Onboarding.Reducer,
    { learn }
  );

  return (
    <stores.Onboarding.Context.Provider
      value={{ state: onboarding, dispatch: dispatchOnboarding }}
    >
      <Routes>
        <Route path="/:taskId" element={<pages.OnboardingPage/>}/>
        <Route path="*" element={<pages.OnboardingPage/>}/>
      </Routes>
    </stores.Onboarding.Context.Provider>
  );
};
