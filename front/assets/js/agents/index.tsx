import { Fragment, render } from "preact";

import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";

import * as stores from "js/agents/stores";
import * as pages from "js/agents/pages";

export default function ({ dom, config }: { dom: HTMLElement, config: any }) {
  const configState = stores.Config.State.fromJSON(config);
  render(
    <BrowserRouter basename={config.baseUrl}>
      <stores.Config.Context.Provider value={configState}>
        <Routes>
          <Route index element={<pages.ActivityMonitor.Page/>}/>
          <Route path="/self_hosted" element={<pages.SelfHosted.Layout/>}>
            <Route path="new" element={<pages.SelfHosted.New/>}/>
            <Route path=":agent" element={<pages.SelfHosted.Agent/>}>
              {configState.accessProvider.canManageAgents() && (
                <Fragment>
                  <Route path="settings" element={<pages.SelfHosted.Edit/>}/>
                  <Route path="disable_all" element={<pages.SelfHosted.DisableAll/>}/>
                  <Route path="delete" element={<pages.SelfHosted.Delete/>}/>
                  <Route path="reset" element={<pages.SelfHosted.ResetToken/>}/>
                </Fragment>
              )}
              <Route path="*" element={<Navigate to="." replace/>}/>
            </Route>
          </Route>
        </Routes>
      </stores.Config.Context.Provider>
    </BrowserRouter>,
    dom
  );
}
