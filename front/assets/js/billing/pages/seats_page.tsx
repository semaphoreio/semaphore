import { Fragment } from "preact";
import { Seats } from "../types";
import * as stores from "../stores";
import * as toolbox from "js/toolbox";
import * as components from "../components";
import { useContext, useLayoutEffect, useReducer } from "preact/hooks";

export const SeatsPage = () => {
  return <Fragment>
    <Fragment>
      <div className="flex items-center justify-between">
        <div>
          <div className="inline-flex items-center">
            <p className="mb0 b f3">Seats breakdown</p>
          </div>
          <div className="gray mb3 measure flex items-center">
            <div className="pr2 mr2">Review your seat usage.</div>
          </div>
        </div>
        <components.SpendingSelect/>
      </div>
      <components.PlanFlags/>
    </Fragment>
    <SeatListing/>
  </Fragment>;
};

export const SeatListing = () => {
  const config = useContext(stores.Config.Context);
  const spendings = useContext(stores.Spendings.Context);
  const [state, dispatch] = useReducer(stores.Seats.Reducer, { ... stores.Seats.EmptyState, url: config.seatsUrl } );

  useLayoutEffect(() => {
    if(spendings.state.selectedSpendingId) {
      const url = new URL(state.url, location.origin);
      url.searchParams.set(`spending_id`, spendings.state.selectedSpendingId);

      dispatch({ type: `SET_STATUS`, value: stores.Seats.Status.Loading });
      fetch(url, { credentials: `same-origin` })
        .then((response) => response.json())
        .then((json) => {
          const seats = json.seats.map(Seats.Seat.fromJSON) as Seats.Seat[];
          dispatch({ type: `SET_SEATS`, seats });
          dispatch({ type: `SET_STATUS`, value: stores.Seats.Status.Loaded });
        }).catch((e) => {
          dispatch({ type: `SET_STATUS`, value: stores.Seats.Status.Error });
          dispatch({ type: `SET_STATUS_MESSAGE`, value: `${e as string}` });
        });
    }
  }, [spendings.state.selectedSpendingId]);

  useLayoutEffect(() => {
    if(state.seats.length > 0) {
      let sortedItems: Seats.Seat[] = state.seats;

      switch(state.orderBy) {
        case `type_asc`:
          sortedItems = state.seats.sort((one, two) => (one.originName() <= two.originName() ? -1 : 1));
          dispatch({ type: `SET_SEATS`, seats: sortedItems });
          break;
        case `type_desc`:
          sortedItems = state.seats.sort((one, two) => (one.originName() > two.originName() ? -1 : 1));
          dispatch({ type: `SET_SEATS`, seats: sortedItems });
          break;

        default:
          sortedItems = state.seats.sort((one, two) => one.displayName.localeCompare(two.displayName));
          dispatch({ type: `SET_SEATS`, seats: sortedItems });
          break;
      }
    }
  }, [state.seats, state.orderBy]);


  return (
    <stores.Seats.Context.Provider value={{ state: state, dispatch: dispatch }}>
      <Element/>
    </stores.Seats.Context.Provider>
  );
};


const Element = () => {
  const store = useContext(stores.Seats.Context);
  const seats = store.state.seats;
  const loaded = store.state.status == stores.Seats.Status.Loaded || store.state.status == stores.Seats.Status.Error;

  return (
    <Fragment>
      {!loaded &&
        <Loading/>}
      {loaded &&
        <div className="bb b--black-075 w-100-l mb4 br3 shadow-3 bg-white">
          <div className="flex items-center justify-between ph3 pv2 bb bw1 b--black-075 br3 br--top">
            <div>
              <div className="flex items-center">
                <span className="material-symbols-outlined pr2">group</span>
                <div className="b">Seats usage</div>
              </div>
            </div>
            <div className="flex items-center">
              <div>
                <div className="gray f5 tr">Members: { seats.filter(i => i.origin == Seats.Origin.Member).length }</div>
                <div className="gray f5 tr">Non-members: { seats.filter(i => i.origin != Seats.Origin.Member).length }</div>
              </div>
            </div>
          </div>
          {seats.length == 0 &&
            <ZeroState/>}
          {seats.length > 0 &&
            <List/>}
          <div>
            <div className="flex items-center justify-between pa3 bt bw1 b--black-075">
              <div className="flex items-center pl4">
              </div>
              <div className="flex items-center">
                <div className="b">{ toolbox.Pluralize(seats.length, `seat`, `seats`) }</div>
              </div>
            </div>
          </div>
        </div>
      }
    </Fragment>
  );
};

const Loading = () => {
  return (
    <div className="flex items-center justify-center br3 mt4" style="height: 200px;">
      <div className="flex items-center">
        <toolbox.Asset
          path="images/spinner-2.svg"
          width="20"
          height="20"
        />
        <span className="ml1 gray">Loading data, please wait&hellip;</span>
      </div>
    </div>
  );
};

const ZeroState = () => {
  return (
    <div className="tc pt5 pb5">
      <toolbox.Asset
        path="images/ill-curious-girl.svg"
        width="60"
        height="80"
      />
      <h4 className="f4 mt2 mb0">No seats</h4>
      <p className="f4 mb0 measure center">Your organization used no seats in this period</p>
    </div>
  );
};

const List = () => {
  const store = useContext(stores.Seats.Context);

  const orderBy = store.state.orderBy;
  const seats = store.state.seats;

  const changeOrder = (orderBy: string) => () => {
    store.dispatch({ type: `ORDER_BY`, value: orderBy });
  };

  const columnFilter = (displayName: string, name: string) => {
    const isAsc = orderBy && orderBy == `${name}_asc`;
    const isDesc = orderBy && orderBy == `${name}_desc`;
    const isNone = !isAsc && !isDesc;
    let order = ``;

    if (isDesc) {
      order = ``;
    } else if(isAsc) {
      order = `${name}_desc`;
    } else {
      order = `${name}_asc`;
    }

    return (
      <div
        onClick={changeOrder(order)}
        className="gray pointer"
        style="user-select: none;"
      >
        <div className={`flex`}>
          <span className={ isNone ? `` : `b`}>{displayName}</span>
          {isAsc && <i className="material-symbols-outlined">arrow_drop_down</i>}
          {isDesc && <i className="material-symbols-outlined">arrow_drop_up</i>}
          {isNone && <i className="material-symbols-outlined">unfold_more</i>}
        </div>
      </div>
    );
  };

  return (
    <div>
      <div className="bb b--black-075 pv1">
        <div className="flex justify-between ph3 pv2">
          <div className="gray">
            <span>User</span>
          </div>
          <div>
            {columnFilter(`Type`, `type`)}
          </div>
        </div>
      </div>
      {seats.map((seat, i) => <SeatItem
        seat={seat}
        key={i}
        lastItem={seats.length == (i + 1)}
      />)}
    </div>
  );
};

const SeatItem = ({ seat, lastItem }: { seat: Seats.Seat, lastItem: boolean }) => {
  return (
    <div className={lastItem ? `` : `bb b--black-075`}>
      <div className="pv1">
        <div className="flex items-center-ns">
          <div className="w-100 ph3 pv2">
            <div className="flex-ns items-center">
              <div className="w-60-ns flex items-center b">
                <div style="width: 26px;" className="mr2 tc flex justify-center content-center">
                  <toolbox.Asset
                    path={seat.icon}
                    width={`${seat.iconWidth.toString()}`}
                    height={`${seat.iconHeight.toString()}`}
                  />
                </div>
                <span className="link db dark-gray">{seat.displayName}</span>
              </div>
              <div className="w-40-ns tr-ns tnum">{seat.originName()}</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
