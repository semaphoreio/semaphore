import * as pages from "./pages";
import { h } from "preact";
import { useEffect } from "preact/hooks";
import { Routes, Route, useLocation } from "react-router-dom";
import { Userpilot } from "userpilot";

export const App = () => {
  const location = useLocation();

  useEffect(() => {
    Userpilot.reload();
  }, [location]);

  return (
    <Routes>
      <Route path="" element={<pages.FlakyTestsPage/>}/>
      <Route path="/:testId" element={<pages.FlakyTestDetails/>}/>
    </Routes>
  );
};
