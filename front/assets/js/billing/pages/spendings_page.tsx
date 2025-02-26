import { Fragment } from "preact";
import { useContext } from "preact/hooks";
import * as stores from "../stores";
import * as components from "../components";

export const SpendingsPage = () => {
  const config = useContext(stores.Config.Context);
  const spendings = useContext(stores.Spendings.Context);
  const currentSpending = spendings.state.selectedSpending;

  const csvUrl = new URL(config.spendingCsvUrl, location.origin);
  csvUrl.searchParams.set(`spending_id`, currentSpending.id);

  return (
    <Fragment>
      <Fragment>
        <div className="flex items-center justify-between">
          <div>
            <div className="inline-flex items-center">
              <p className="mb0 b f3">Spending breakdown</p>
            </div>
            <div className="gray mb3 measure flex items-center">
              <div className="pr2 mr2">Review your spending in detail.</div>
            </div>
          </div>
          <components.SpendingSelect/>
        </div>
        <components.PlanFlags/>
      </Fragment>
      <div className="tr mv2">
        <a className="btn btn-secondary" href={csvUrl.toString()}>Download .csv</a>
      </div>
      {currentSpending?.groups.map((group, idx) => <components.SpendingGroup group={group} key={idx}/>)}
    </Fragment>
  );
};
