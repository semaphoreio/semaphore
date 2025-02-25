
import { useContext } from "preact/hooks";
import * as store from "../stores";

export const TableHeaders = ({ tableSize }: { tableSize: number, }) => {
  const { state, dispatch } = useContext(store.FlakyTest.Context);
  const sortOrder = state.sortOrder;

  const columnFilter = (displayName: string, name: string, className: string) => {
    const isAsc = sortOrder && sortOrder[0] == name && sortOrder[1] == `asc`;
    const isDesc = sortOrder && sortOrder[0] == name && sortOrder[1] == `desc`;
    const isNone = !isAsc && !isDesc;
    let order = [``, ``];

    // rotate sorting order
    if (isDesc) {
      order = [name, `asc`];
    } else if(isAsc) {
      order = [`total_disruptions_count`, `desc`];
    } else {
      order = [name, `desc`];
    }

    const changeOrder = (order: string[]) => {
      dispatch({ type: `SET_SORT_ORDER`, value: order });
    };

    return (
      <div onClick={() => changeOrder(order) } className="pointer" style="user-select: none;">
        <div className={`flex ${className}`}>
          <span className="b">{displayName}</span>
          {isDesc && <i className="material-symbols-outlined">expand_more</i>}
          {isAsc && <i className="material-symbols-outlined">expand_less</i>}
          {isNone && <i className="material-symbols-outlined">unfold_more</i>}
        </div>
      </div>
    );
  };


  return (
    <div className="flex-m b pv2">
      <div className="w-25-m">
                Flaky Tests ({tableSize})
      </div>
      <div className="w-10-m flex items-center justify-center c-billing-table-sort">
                Labels
      </div>

      <div className="w-10-m flex items-center justify-center c-billing-table-sort">
        {columnFilter(`Age`, `age`, ``)}
      </div>

      <div className="w-10-m flex items-center justify-center c-billing-table-sort">
        {columnFilter(`Last flaked`, `latest_disruption_timestamp`, ``)}
      </div>

      <div className="w-25-m flex items-center justify-center c-billing-table-sort--active">
                Disruption History
      </div>

      <div className="w-10-m flex items-center justify-center c-billing-table-sort--active">
        {columnFilter(`Disruptions`, `total_disruptions_count`, ``)}
      </div>

      <div className="w-10-m flex items-center justify-center c-billing-table-sort">
                Actions
      </div>
    </div>
  );
};
