import { useState } from "preact/hooks";
import * as types from "../types";

interface TTLSelectorProps {
  ttlConfig?: types.TTLConfig;
  onTTLChange: (config: types.TTLConfig) => void;
  disabled?: boolean;
}

const TTL_PRESETS = [
  { label: `1 hour`, value: 1 },
  { label: `4 hours`, value: 4 },
  { label: `8 hours`, value: 8 },
  { label: `1 day`, value: 24 },
  { label: `3 days`, value: 72 },
  { label: `1 week`, value: 168 },
  { label: `Never expire`, value: null },
];

export const TTLSelector = ({
  ttlConfig,
  onTTLChange,
  disabled = false,
}: TTLSelectorProps) => {
  const [useCustomTTL, setUseCustomTTL] = useState(
    ttlConfig?.default_ttl_hours !== null &&
      ttlConfig?.default_ttl_hours !== undefined
      ? !TTL_PRESETS.some((p) => p.value === ttlConfig.default_ttl_hours)
      : false
  );

  const currentConfig = ttlConfig || {
    default_ttl_hours: 24,
    allow_extension: true,
  };

  const updateConfig = (field: keyof types.TTLConfig, value: any) => {
    onTTLChange({
      ...currentConfig,
      [field]: value,
    });
  };

  return (
    <div className="w-100">
      <div className="mb3">
        <label className="db fw6 mb2">Default Instance Lifetime</label>
        <div>
          <div className="flex flex-wrap gap-2 mb2">
            {TTL_PRESETS.map((preset) => (
              <button
                key={preset.value === null ? `never` : preset.value}
                type="button"
                className={`btn ${
                  !useCustomTTL &&
                  ((preset.value === null &&
                    currentConfig.default_ttl_hours === null) ||
                    (preset.value !== null &&
                      currentConfig.default_ttl_hours === preset.value))
                    ? `btn-primary`
                    : `btn-secondary`
                }`}
                onClick={() => {
                  setUseCustomTTL(false);
                  updateConfig(`default_ttl_hours`, preset.value);
                }}
                disabled={disabled}
              >
                {preset.label}
              </button>
            ))}
            <button
              type="button"
              className={`btn ${
                useCustomTTL ? `btn-primary` : `btn-secondary`
              }`}
              onClick={() => setUseCustomTTL(true)}
              disabled={disabled}
            >
              Custom
            </button>
          </div>

          {useCustomTTL && (
            <div className="flex items-center gap-2">
              <input
                type="number"
                className="form-control pa1 w4"
                value={currentConfig.default_ttl_hours}
                onChange={(e) =>
                  updateConfig(
                    `default_ttl_hours`,
                    parseInt((e.target as HTMLInputElement).value) || 1
                  )
                }
                min={1}
                max={8760}
                disabled={disabled}
              />
              <span className="gray">hours</span>
            </div>
          )}
        </div>
      </div>

      {currentConfig.default_ttl_hours !== null && (
        <div className="mb3">
          <label className="flex items-center">
            <input
              type="checkbox"
              checked={currentConfig.allow_extension}
              onChange={(e) =>
                updateConfig(
                  `allow_extension`,
                  (e.target as HTMLInputElement).checked
                )
              }
              className="mr2"
              disabled={disabled}
            />
            <span>Allow users to extend lifetime before expiration</span>
          </label>
        </div>
      )}
    </div>
  );
};
