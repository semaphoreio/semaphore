import { Routes, Route } from "react-router-dom";
import { EnvironmentsListPage } from "./pages/EnvironmentsListPage";
import { CreateEnvironmentPage } from "./pages/CreateEnvironmentPage";
import { EnvironmentDetailsPage } from "./pages/EnvironmentDetailsPage";
import { EditEnvironmentPage } from "./pages/EditEnvironmentPage";

export const App = () => {
  return (
    <Routes>
      <Route path="" element={<EnvironmentsListPage/>}/>
      <Route path="/new" element={<CreateEnvironmentPage/>}/>
      <Route path="/:id" element={<EnvironmentDetailsPage/>}/>
      <Route path="/:id/edit" element={<EditEnvironmentPage/>}/>
    </Routes>
  );
};
