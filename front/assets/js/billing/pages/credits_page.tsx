import { Fragment } from "preact";
import * as stores from "../stores";
import * as components from "../components";
import * as types from "../types";
import { useContext, useLayoutEffect, useReducer } from "preact/hooks";

export const CreditsPage = () => {
  const config = useContext(stores.Config.Context);
  const [state, dispatch] = useReducer(stores.Credits.Reducer, {
    ...stores.Credits.EmptyState,
    url: config.creditsUrl,
  });

  useLayoutEffect(() => {
    const url = new URL(config.creditsUrl, location.origin);

    dispatch({ type: `SET_STATUS`, value: stores.Prices.Status.Loading });
    dispatch({ type: `SET_AVAILABLE`, available: [] });
    dispatch({ type: `SET_BALANCE`, balance: [] });

    fetch(url, { credentials: `same-origin` })
      .then((response) => response.json())
      .then((json) => {
        const available = json.available.map(types.Credits.Available.fromJSON) as types.Credits.Available[];
        const balance = json.balance.map(types.Credits.Balance.fromJSON) as types.Credits.Balance[];

        dispatch({ type: `SET_AVAILABLE`, available });
        dispatch({ type: `SET_BALANCE`, balance });
        dispatch({ type: `SET_STATUS`, value: stores.Credits.Status.Loaded });
      })
      .catch((e) => {
        dispatch({ type: `SET_STATUS`, value: stores.Credits.Status.Error });
        dispatch({ type: `SET_STATUS_MESSAGE`, value: `${e as string}` });
      });
  }, []);

  return (
    <Fragment>
      <Fragment>
        <div className="flex items-center justify-between">
          <div>
            <div className="inline-flex items-center">
              <p className="mb0 b f3">Credits balance</p>
            </div>
            <div className="gray mb3 flex items-center">
              <div className="pr2 mr2">
                Review your remaining pre-paid and gift credits, and check your spending history.
              </div>
            </div>
          </div>
        </div>
        <components.PlanFlags/>
      </Fragment>
      <div className="center">
        <components.AvailableCredits credits={state.available}/>
        <components.CreditsBalance credits={state.balance}/>
      </div>
    </Fragment>
  );
};
