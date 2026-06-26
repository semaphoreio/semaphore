export interface RefreshResponse {
  state: string;
  message?: string;
  retry_after?: number;
}

type RefreshOutcome =
  | { kind: `rate_limited`, cooldown: number, ok: false, }
  | { kind: `started`, startCooldown: boolean, ok: true, }
  | { kind: `done`, reloadNow: boolean, ok: true, }
  | { kind: `error`, message: string, ok: false, };

const DEFAULT_ERROR = `Could not refresh repositories.`;

// Pure decision for what a refresh response means, so the side-effecting
// component (cooldown timer, reload, notices) and its tests share one source of
// truth. `slug` present means a targeted refresh; absent means full/org.
//
// 429 is handled before the empty-body check on purpose: a rate-limited
// response with no body must still start the cooldown (fall back to
// defaultCooldown), not be swallowed as a generic error.
export const decideRefreshOutcome = (
  status: number,
  data: RefreshResponse | null | undefined,
  error: string | undefined,
  slug: string | undefined,
  defaultCooldown: number
): RefreshOutcome => {
  if (status === 429) {
    return { kind: `rate_limited`, cooldown: data?.retry_after ?? defaultCooldown, ok: false };
  }

  if (!data) {
    return { kind: `error`, message: error || DEFAULT_ERROR, ok: false };
  }

  switch (data.state) {
    case `started`:
    case `already_running`:
      return { kind: `started`, startCooldown: !slug, ok: true };
    case `done`:
      return { kind: `done`, reloadNow: Boolean(slug), ok: true };
    default:
      return { kind: `error`, message: data.message || error || DEFAULT_ERROR, ok: false };
  }
};

// Human-friendly cooldown: rounded minutes above a minute, raw seconds at or below.
export const formatCooldown = (seconds: number): string => {
  if (seconds > 60) {
    const minutes = Math.round(seconds / 60);
    return `${minutes} ${minutes === 1 ? `minute` : `minutes`}`;
  }

  return `${seconds}s`;
};
