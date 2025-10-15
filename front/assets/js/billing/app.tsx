import { Fragment, VNode } from "preact";
import * as pages from "./pages";
import * as components from "./components";
import * as stores from "./stores";
import * as types from "./types";
import { Routes, Route, Navigate } from "react-router-dom";
import { Spendings } from "./types";
import {
  useReducer,
  useLayoutEffect,
  useState,
  useContext,
} from "preact/hooks";
import { URLState } from "js/toolbox";

interface Props {
  config: stores.Config.State;
}

export const App = (props: Props) => {
  const spendings = props.config.spendings.map(Spendings.Spending.fromJSON);
  const selectedSpendingId = props.config.selectedSpendingId;
  const currentSpending = Spendings.Spending.fromJSON(
    props.config.currentSpending,
  );

  return (
    <SpendingsProvider
      spendings={spendings}
      selectedSpendingId={selectedSpendingId}
      currentSpending={currentSpending}
    >
      <Layout/>
    </SpendingsProvider>
  );
};
const Layout = () => {
  const [layout, setLayout] = useState(<CompactLayout/>);
  const { state } = useContext(stores.Spendings.Context);

  useLayoutEffect(() => {
    const queryParams = new URLSearchParams(window.location.search);
    const preview = queryParams.get(`__preview`);
    if (preview) {
      setLayout(<RegularLayout/>);
    } else {
      switch (state.selectedSpending?.layout) {
        case types.Spendings.SpendingLayout.Compact:
          setLayout(<CompactLayout/>);
          break;
        case types.Spendings.SpendingLayout.Regular:
          setLayout(<RegularLayout/>);
          break;

        case types.Spendings.SpendingLayout.Classic:
          setLayout(<ClassicLayout/>);
          break;

        case types.Spendings.SpendingLayout.UpdatePayment:
          setLayout(<UpdatePaymentLayout/>);
          break;
      }
    }
  }, [state.selectedSpending]);

  return (
    <div className="bg-washed-gray mt4 pa3 pa4-l br3 ba b--black-075">
      <div className="flex-l">{layout}</div>
    </div>
  );
};

const UpdatePaymentLayout = () => {
  return <pages.UpdatePaymentsPage/>;
};

const CompactLayout = () => {
  return <pages.CompactSpendingsPage/>;
};

const ClassicLayout = () => {
  return <pages.ClassicSpendingsPage/>;
};

const RegularLayout = () => {
  const config = useContext(stores.Config.Context);

  const hasPlans = config.availablePlans.length > 1;

  return (
    <Fragment>
      <div className="w6-l flex-shrink-0 pr4-l pb3">
        <components.Navigation/>
      </div>
      <div className="w-100-l">
        <Routes>
          <Route path="/" element={<Navigate to="/overview"/>}/>
          <Route path="/overview" element={<pages.OverviewPage/>}/>
          {hasPlans && <Route path="/plans" element={<pages.PlansPage/>}/>}
          <Route path="/seats" element={<pages.SeatsPage/>}/>
          <Route path="/spending" element={<pages.SpendingsPage/>}/>
          {config.projectSpendings && (
            <Route path="/projects" element={<pages.ProjectsPage/>}/>
          )}
          {config.projectSpendings && (
            <Route
              path="/projects/:projectName"
              element={<pages.ProjectPage/>}
            />
          )}
          <Route path="/credits" element={<pages.CreditsPage/>}/>
          <Route path="*" element={<Navigate to="/overview"/>}/>
        </Routes>
      </div>
    </Fragment>
  );
};

const SpendingsProvider = ({
  children,
  spendings,
  currentSpending,
  selectedSpendingId,
}: {
  children?: VNode<any>[] | VNode<any>;
  spendings: Spendings.Spending[];
  currentSpending: Spendings.Spending;
  selectedSpendingId: string;
}) => {
  const [state, dispatch] = useReducer(stores.Spendings.Reducer, {
    ...stores.Spendings.EmptyState,
    spendings,
  });

  useLayoutEffect(() => {
    dispatch({ type: `SELECT_SPENDING`, value: selectedSpendingId });
    dispatch({ type: `SET_CURRENT_SPENDING`, value: currentSpending });
  }, []);

  useLayoutEffect(() => {
    if (state.selectedSpendingId.length) {
      URLState.set(`spending_id`, state.selectedSpendingId);
    } else {
      URLState.unset(`spending_id`);
    }
  }, [state.selectedSpendingId]);

  return (
    <stores.Spendings.Context.Provider value={{ state, dispatch }}>
      {children}
    </stores.Spendings.Context.Provider>
  );
};
