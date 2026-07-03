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

// Which cooldown a refresh affects: targeted and org refreshes throttle
// independently on the backend, so a `slug` (targeted) and an empty slug (org)
// must update separate cooldown state — never a shared one.
export type RefreshScope = `targeted` | `org`;

export const cooldownScope = (slug: string | undefined): RefreshScope =>
  slug ? `targeted` : `org`;

// Control gating, kept pure so the component and tests share one definition.
// Each control is blocked only by its OWN cooldown (plus the shared in-flight
// flag) — a targeted cooldown must not disable the org control, or vice versa.
export const isTargetedRefreshDisabled = (
  validSlug: string | null,
  isRefreshing: boolean,
  targetedCooldownLeft: number
): boolean => !validSlug || isRefreshing || targetedCooldownLeft > 0;

export const isOrgRefreshLocked = (
  isRefreshing: boolean,
  orgCooldownLeft: number
): boolean => isRefreshing || orgCooldownLeft > 0;

// Post-enqueue polling: the refresh RPC only enqueues async Sidekiq work, so the
// UI keeps polling the repository list (indicator up) until the synced repo shows
// up (targeted, detectable) or a bounded best-effort window elapses (org, which
// has no client-side completion signal). Pure policy; the component owns timers.
export const SYNC_POLL_MAX_ATTEMPTS: Record<RefreshScope, number> = {
  targeted: 20,
  org: 4,
};

// Pages to scan per poll tick when hunting for a targeted slug (it may not be on
// page 1); org needs no detection, so it reads a single page.
export const SYNC_POLL_MAX_PAGES = 5;

export const repositoriesIncludeSlug = (
  repos: ReadonlyArray<{ full_name: string }>,
  slug: string
): boolean => {
  const target = slug.toLowerCase();
  return repos.some((repo) => repo.full_name.toLowerCase() === target);
};

// Delay before poll attempt `attempt` (1-based). Targeted polls at a steady short
// interval; org backs off (5s, 10s, 15s, 20s…) since it cannot detect completion.
export const nextSyncPollDelayMs = (attempt: number, scope: RefreshScope): number =>
  scope === `targeted` ? 3000 : Math.min(attempt * 5000, 20000);

export const shouldStopPolling = (args: {
  scope: RefreshScope,
  attempt: number,
  maxAttempts: number,
  found: boolean,
}): boolean => {
  if (args.scope === `targeted` && args.found) return true;
  return args.attempt >= args.maxAttempts;
};
