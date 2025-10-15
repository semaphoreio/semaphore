
import { useContext } from "preact/hooks";
import * as stores from "../stores";
import { DateRangeItem } from "../types";

export const DateSelect = ({ items }: { items: DateRangeItem[] }) => {
  const store = useContext(stores.OrganizationHealth.Context);
  const state = store.state;

  const setSelectedDateFromEvent = (event: Event) => {
    const target = event.target as HTMLSelectElement;
    const index = parseInt(target.value, 10);
    store.dispatch({ type: `SELECT_DATES`, value: index });
  };

  const periodRange = items.filter((item) => item.type == `period`);
  const monthRange = items.filter((item) => item.type == `month`);

  return (
    <select className="db form-control mr2" value={ state.selectedDateIndex} onChange={ setSelectedDateFromEvent }>
      <optgroup label="Per period">
        {periodRange.map((item) => (
          <option key={item.index} value={item.index}>{item.label}</option>
        ))}
      </optgroup>
      <optgroup label="Per month">
        {monthRange.map((item) => (
          <option key={item.index} value={item.index}>{item.label}</option>
        ))}
      </optgroup>
    </select>
  );
};
