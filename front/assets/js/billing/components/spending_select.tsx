
import { h } from "preact";
import { useContext } from "preact/hooks";
import * as stores from "../stores";

export const SpendingSelect = () => {
  const store = useContext(stores.Spendings.Context);
  const state = store.state;

  const setSelectedSpendingFromEvent = (event: Event) => {
    const target = event.target as HTMLSelectElement;
    const selectedSpendingId = target.value;
    store.dispatch({ type: `SELECT_SPENDING`, value: selectedSpendingId });
  };

  return (
    <div className="tr">
      <div className="gray flex items-center flex-row-reverse">
        <select className="db form-control mb0-m form-control-tiny" value={state.selectedSpendingId} onChange={ setSelectedSpendingFromEvent }>
          {state.spendings.map((spending, idx) => (
            <option key={idx} value={spending.id}>{spending.name}</option>
          ))}
        </select>
      </div>
    </div>
  );
};
