import { Fragment } from "preact";
import { useState } from "preact/hooks";
import * as types from "../types";

interface Props {
  group: types.Addons.AddonGroup;
  updating: string | null;
  onUpdate: (addonName: string, enabled: boolean) => void;
}

export const TierSelector = ({ group, updating, onUpdate }: Props) => {
  const isUpdating = updating !== null;
  const isExclusive = group.type === types.Addons.GroupType.Exclusive;
  const [pendingAction, setPendingAction] = useState<{ addonName: string, displayName: string, enabled: boolean } | null>(null);

  const handleConfirm = () => {
    if (!pendingAction) return;
    onUpdate(pendingAction.addonName, pendingAction.enabled);
    setPendingAction(null);
  };

  return (
    <div className="bb b--black-075 br3 shadow-3 bg-white mb4">
      <div className="ph3 pv3 bb bw1 b--black-075 br3 br--top">
        <div className="f4 b">{group.displayName}</div>
        {group.description && (
          <div className="f5 gray mt1">{group.description}</div>
        )}
      </div>

      <div>
        {group.addons.map((addon, idx) => {
          const isThisUpdating = updating === addon.name;
          const isLast = idx === group.addons.length - 1;

          return (
            <div
              key={addon.name}
              className={
                `flex items-center justify-between ph3 pv3 ` +
                (!isLast ? `bb b--black-10 ` : ``) +
                (addon.enabled ? `bg-lightest-green ` : ``) +
                (!addon.modifiable || isUpdating ? `o-70 ` : ``)
              }
            >
              <div className="flex-auto">
                <div className="flex items-center">
                  <span className="b">{addon.displayName}</span>
                  {addon.price && (
                    <span className="ml2 f6 gray">{addon.price}</span>
                  )}
                  {addon.enabled && !isThisUpdating && (
                    <span className="ml2 f7 fw6 ph2 pv1 br2 bg-green white">Active</span>
                  )}
                  {isThisUpdating && (
                    <span className="ml2 f7 gray i">Updating...</span>
                  )}
                  {!addon.modifiable && (
                    <span className="ml2 f7 gray i">Contact sales</span>
                  )}
                </div>
                {addon.description && (
                  <div className="f6 gray mt1">{addon.description}</div>
                )}
              </div>

              {addon.modifiable && (
                <div className="ml3 flex-shrink-0">
                  {!addon.enabled && (
                    <button
                      className="btn btn-primary f6"
                      disabled={isUpdating}
                      onClick={() => setPendingAction({
                        addonName: addon.name,
                        displayName: addon.displayName,
                        enabled: true,
                      })}
                    >
                      {isExclusive ? `Select` : `Enable`}
                    </button>
                  )}
                  {addon.enabled && (
                    <button
                      className="btn btn-secondary f6"
                      disabled={isUpdating}
                      onClick={() => setPendingAction({
                        addonName: addon.name,
                        displayName: addon.displayName,
                        enabled: false,
                      })}
                    >
                      {isExclusive ? `Deselect` : `Disable`}
                    </button>
                  )}
                </div>
              )}
            </div>
          );
        })}
      </div>

      {pendingAction && (
        <div className="ph3 pv3 bt b--black-075 bg-washed-yellow">
          <div className="flex items-center justify-between">
            <div className="f5">
              {pendingAction.enabled ? (
                <Fragment>
                  Enable <span className="b">{pendingAction.displayName}</span>?
                  <span className="ml1 gray">This may affect your billing.</span>
                </Fragment>
              ) : (
                <Fragment>
                  Disable <span className="b">{pendingAction.displayName}</span>?
                </Fragment>
              )}
            </div>
            <div className="flex" style={{ gap: `8px` }}>
              <button
                className="btn btn-primary"
                onClick={handleConfirm}
                disabled={isUpdating}
              >
                Confirm
              </button>
              <button
                className="btn btn-secondary"
                onClick={() => setPendingAction(null)}
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
