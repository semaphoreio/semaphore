import { h } from "preact";
import * as stores from "./stores";
import * as pages from "./pages";


interface Props {
  config: stores.Config.State;
}

export const App = (props: Props) => {
  return (
    <stores.Config.Context.Provider value={props.config}>
      <pages.OverviewPage/>
    </stores.Config.Context.Provider>
  );
};