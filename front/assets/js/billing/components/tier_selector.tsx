import { useState } from "preact/hooks";
import * as types from "../types";

interface Props {
  group: types.Addons.AddonGroup;
  updating: string | null;
  onUpdate: (addonName: string, enabled: boolean) => void;
}

const selectedBorder = `2px solid #19a974`;

export const TierSelector = ({ group, updating, onUpdate }: Props) => {
  const isUpdating = updating !== null;
  const currentAddon = group.addons.find((a) => a.enabled);
  const currentValue = currentAddon?.name ?? null;
  const [selected, setSelected] = useState<string | null>(currentValue);

  const onCooldown = currentAddon !== undefined && !currentAddon.modifiable;
  const hasChanged = selected !== currentValue;
  const isDisabling = currentAddon && !selected;
  const selectedAddon = group.addons.find((a) => a.name === selected);

  const handleSave = () => {
    if (!hasChanged) return;

    if (currentAddon && selected !== currentAddon.name) {
      onUpdate(currentAddon.name, false);
    }

    if (selected) {
      onUpdate(selected, true);
    }
  };

  return (
    <div className="bb b--black-075 br3 shadow-3 bg-white">
      <div className="ph3 pv3 bb bw1 b--black-075 br3 br--top">
        <div className="f4 b">{group.displayName}</div>
        {group.description && (
          <div className="f5 gray mt1">{group.description}</div>
        )}
        {onCooldown && (
          <div className="f6 orange mt1">Selection locked for 24 hours. You can still disable the current add-on.</div>
        )}
      </div>

      <div>
        <label
          className={
            `flex items-center ph3 pv3 bb b--black-10 pointer ` +
            (!currentValue ? `bg-lightest-green ` : ``)
          }
          style={hasChanged && !selected ? { border: selectedBorder, borderRadius: `4px`, margin: `-2px` } : undefined}
        >
          <input
            type="radio"
            name={group.name}
            checked={!selected}
            disabled={isUpdating}
            onChange={() => setSelected(null)}
            className="mr3"
            style={{ width: `18px`, height: `18px`, flexShrink: 0 }}
          />
          <div className="flex-auto">
            <div className="flex items-center">
              <span className="b">Disabled</span>
              <span className="ml2 f6 gray">$ 0.00</span>
              {!currentValue && (
                <span className="ml2 f7 fw6 ph2 pv1 br2 bg-green white">Current</span>
              )}
            </div>
            <div className="f6 gray mt1">No {group.displayName.toLowerCase()} add-on selected.</div>
          </div>
        </label>

        {group.addons.map((addon, idx) => {
          const isLast = idx === group.addons.length - 1;
          const isCurrent = addon.enabled;
          const isSelected = selected === addon.name;
          const locked = onCooldown && !addon.enabled;

          return (
            <label
              key={addon.name}
              className={
                `flex items-center ph3 pv3 ` +
                (!isLast ? `bb b--black-10 ` : ``) +
                (isCurrent ? `bg-lightest-green ` : ``) +
                (locked ? `o-70 ` : `pointer `)
              }
              style={{
                ...(locked ? { pointerEvents: `none` } : {}),
                ...(hasChanged && isSelected ? { border: selectedBorder, borderRadius: `4px`, margin: `-2px` } : {}),
              }}
            >
              <input
                type="radio"
                name={group.name}
                checked={isSelected}
                disabled={isUpdating || locked}
                onChange={() => setSelected(addon.name)}
                className="mr3"
                style={{ width: `18px`, height: `18px`, flexShrink: 0 }}
              />

              <div className="flex-auto">
                <div className="flex items-center">
                  <span className="b">{addon.displayName}</span>
                  {addon.price && (
                    <span className="ml2 f6 gray">{addon.price}</span>
                  )}
                  {isCurrent && (
                    <span className="ml2 f7 fw6 ph2 pv1 br2 bg-green white">Current</span>
                  )}
                </div>
                {addon.description && (
                  <div className="f6 gray mt1">{addon.description}</div>
                )}
              </div>
            </label>
          );
        })}
      </div>

      {hasChanged && (
        <div className="ph3 pv3 bt b--black-075 bg-washed-yellow">
          <div className="flex items-center justify-between">
            <div className="f5">
              {isDisabling ? (
                <span>
                  Disable <span className="b">{currentAddon.displayName}</span>?
                  <span className="ml1 gray">You wont be able to select an add-on for the next 24 hours.</span>
                </span>
              ) : (
                <span>
                  Switch to <span className="b">{selectedAddon?.displayName}</span>?
                  <span className="ml1 gray">This may affect your billing.</span>
                </span>
              )}
            </div>
            <div className="flex" style={{ gap: `8px` }}>
              <button
                className="btn btn-primary"
                onClick={handleSave}
                disabled={isUpdating}
              >
                {isUpdating ? `Saving...` : `Save`}
              </button>
              <button
                className="btn btn-secondary"
                onClick={() => setSelected(currentValue)}
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
