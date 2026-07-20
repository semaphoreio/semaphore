import { Fragment } from "preact";
import * as pages from "./pages";
import { Routes, Route, Navigate, useSearchParams } from "react-router-dom";
import { useContext, useEffect, useState } from "preact/hooks";
import * as stores from "./stores";

export const App = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const [redirectToAfterSetup, setRedirectToAfterSetup] = useState<string | null>(null);
  const { ...config } = useContext(stores.Config.Context);

  useEffect(() => {
    const redirectTo = searchParams.get(`redirect_to`);
    if (redirectTo) {
      setRedirectToAfterSetup(redirectTo);
      searchParams.delete(`redirect_to`);
      setSearchParams(searchParams);
    }
  }, []);

  return (
    <Fragment>
      <stores.Config.Context.Provider value={{ ...config, redirectToAfterSetup: redirectToAfterSetup }}>
        <Routes>
          <Route path="/" element={<pages.HomePage/>}/>
          <Route path="/github_app/setup" element={<pages.GithubAppSetup/>}/>
          <Route path="/:type" element={<pages.IntegrationPage/>}/>
          <Route path="*" element={<Navigate to="/"/>}/>
        </Routes>
      </stores.Config.Context.Provider>
    </Fragment>
  );
};
