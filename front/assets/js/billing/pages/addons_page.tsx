import { Fragment } from "preact";
import { useContext, useLayoutEffect, useReducer } from "preact/hooks";
import * as stores from "../stores";
import * as components from "../components";
import * as types from "../types";

export const AddonsPage = () => {
  const config = useContext(stores.Config.Context);
  const [state, dispatch] = useReducer(stores.Addons.Reducer, {
    ...stores.Addons.EmptyState,
    url: config.addonsUrl || ``,
  });

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

  useLayoutEffect(() => {
    fetchGroups();
  }, []);

  const handleUpdate = (addonName: string, enabled: boolean) => {
    if (!config.updateAddonUrl) return;

    dispatch({ type: `SET_UPDATING`, value: addonName });

    fetch(config.updateAddonUrl, {
      method: `POST`,
      credentials: `same-origin`,
      headers: {
        "Content-Type": `application/json`,
        "x-csrf-token": getCSRFToken(),
      },
      body: JSON.stringify({ addon_name: addonName, enabled }),
    })
      .then((response) => response.json())
      .then((json) => {
        dispatch({ type: `SET_UPDATING`, value: null });
        if (json.ok) {
          fetchGroups();
        }
      })
      .catch(() => {
        dispatch({ type: `SET_UPDATING`, value: null });
      });
  };

  return (
    <Fragment>
      <div className="mb3">
        <p className="mb0 b f3">Add-ons</p>
        <div className="gray measure">
          Manage your support and success tiers. Changes may affect your billing.
        </div>
      </div>

      {state.status === stores.Addons.Status.Loading && (
        <components.Loader.LoadingSpinner text="Loading add-ons..." />
      )}

      {state.status === stores.Addons.Status.Error && (
        <div className="bb b--black-075 br3 shadow-3 bg-white pa3">
          <div className="red">Failed to load add-ons.</div>
        </div>
      )}

      {state.status === stores.Addons.Status.Loaded &&
        state.groups.map((group) => (
          <components.TierSelector
            key={group.name}
            group={group}
            updating={state.updating}
            onUpdate={handleUpdate}
          />
        ))}

      {state.status === stores.Addons.Status.Loaded &&
        state.groups.length === 0 && (
          <div className="bb b--black-075 br3 shadow-3 bg-white pa3">
            <div className="gray tc">No add-ons available.</div>
          </div>
        )}
    </Fragment>
  );
};

const getCSRFToken = (): string => {
  const meta = document.querySelector(`meta[name="csrf-token"]`);
  return meta ? (meta as HTMLMetaElement).content : ``;
};
