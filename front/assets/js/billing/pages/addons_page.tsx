import { Fragment } from "preact";
import { useContext, useEffect, useReducer } from "preact/hooks";
import * as stores from "../stores";
import * as components from "../components";
import * as types from "../types";

export const AddonsPage = () => {
  const config = useContext(stores.Config.Context);
  const [state, dispatch] = useReducer(stores.Addons.Reducer, stores.Addons.EmptyState);

  const fetchGroups = () => {
    if (!config.addonsUrl) return;

    const url = new URL(config.addonsUrl, location.origin);

    dispatch({ type: `SET_STATUS`, value: stores.Addons.Status.Loading });

    fetch(url, { credentials: `same-origin` })
      .then((response) => response.json())
      .then((json) => {
        const groups = json.groups.map(
          types.Addons.AddonGroup.fromJSON
        ) as types.Addons.AddonGroup[];

        dispatch({ type: `SET_GROUPS`, groups });
        dispatch({ type: `SET_STATUS`, value: stores.Addons.Status.Loaded });
      })
      .catch(() => {
        dispatch({ type: `SET_STATUS`, value: stores.Addons.Status.Error });
      });
  };

  useEffect(() => {
    fetchGroups();
  }, []);

  return (
    <Fragment>
      <div className="mb3">
        <p className="mb0 b f3">Add-ons</p>
        <div className="gray measure">
          Overview of your active support and success tiers.
        </div>
      </div>

      {state.status === stores.Addons.Status.Loading && (
        <components.Loader.LoadingSpinner text="Loading add-ons..."/>
      )}

      {state.status === stores.Addons.Status.Error && (
        <div className="bb b--black-075 br3 shadow-3 bg-white pa3">
          <div className="red">Failed to load add-ons.</div>
        </div>
      )}

      {state.status === stores.Addons.Status.Loaded &&
        state.groups.length > 0 && (
        <div className="flex" style={{ gap: `24px` }}>
          {state.groups.map((group) => (
            <div key={group.name} style={{ flex: `1 1 0%`, minWidth: 0 }}>
              <div className="bb b--black-075 br3 shadow-3 bg-white">
                <div className="ph3 pv3 bb bw1 b--black-075 br3 br--top">
                  <div className="f4 b">{group.displayName}</div>
                  {group.description && (
                    <div className="f5 gray mt1">{group.description}</div>
                  )}
                </div>

                {group.addons.map((addon, idx) => {
                  const isLast = idx === group.addons.length - 1;

                  return (
                    <div
                      key={addon.name}
                      className={
                        `flex items-center ph3 pv3 ` +
                          (!isLast ? `bb b--black-10 ` : ``) +
                          (addon.enabled ? `bg-lightest-green ` : ``)
                      }
                    >
                      <div className="flex-auto">
                        <div className="flex items-center">
                          <span className="b">{addon.displayName}</span>
                          {addon.price && (
                            <span className="ml2 f6 gray">{addon.price}</span>
                          )}
                          {addon.enabled && (
                            <span className="ml2 f7 fw6 ph2 pv1 br2 bg-green white">Active</span>
                          )}
                        </div>
                        {addon.description && (
                          <div className="f6 gray mt1">{addon.description}</div>
                        )}
                      </div>
                    </div>
                  );
                })}

                {group.addons.every((a) => !a.enabled) && (
                  <div className="ph3 pv3 gray f6">No add-on active for this group.</div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {state.status === stores.Addons.Status.Loaded &&
        state.groups.length === 0 && (
        <div className="bb b--black-075 br3 shadow-3 bg-white pa3">
          <div className="gray tc">No add-ons available.</div>
        </div>
      )}
    </Fragment>
  );
};
