import * as pages from "./pages";

import { Routes, Route } from "react-router-dom";

export const App = () => {
  return (
    <Routes>
      <Route path="" element={<pages.FlakyTestsPage/>}/>
      <Route path="/:testId" element={<pages.FlakyTestDetails/>}/>
    </Routes>
  );
};
