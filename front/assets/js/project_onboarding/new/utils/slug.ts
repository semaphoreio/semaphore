export const REPOSITORY_SLUG_REGEX = /^[A-Za-z0-9][A-Za-z0-9-]{0,38}\/[A-Za-z0-9._-]{1,100}$/;

export const parseRepositorySlug = (query: string): string | null => {
  const trimmed = query.trim();
  return REPOSITORY_SLUG_REGEX.test(trimmed) ? trimmed : null;
};

const PATH_SEGMENT_REGEX = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;

const PROVIDER_HOSTS: Record<string, readonly string[]> = {
  github_app: [`github.com`],
  github_oauth_token: [`github.com`],
  bitbucket: [`bitbucket.org`],
  gitlab: [`gitlab.com`],
};

// Whether a pasted URL's authority (which may include `user@` and `:port`)
// belongs to the selected provider's host — so a non-provider domain like
// www.randomdomain.com isn't reduced to an "owner/repo" slug. With no provider,
// any known provider host is accepted.
const hostMatchesProvider = (authority: string, provider?: string): boolean => {
  const host = authority.split(`@`).pop()?.split(`:`)[0].toLowerCase().replace(/^www\./, ``) || ``;
  const allowed = provider ? PROVIDER_HOSTS[provider] : Object.values(PROVIDER_HOSTS).flat();
  return !!allowed && allowed.includes(host);
};

const gitlabProjectPath = (path: string): string | null => {
  const segments = path.split(`/-/`)[0].replace(/\.git$/, ``).split(`/`).filter(Boolean);

  if (segments.length >= 2 && segments.every((segment) => PATH_SEGMENT_REGEX.test(segment))) {
    return segments.join(`/`);
  }

  return null;
};

// Reduces a pasted repo URL (web, git/ssh, or scp remote) to its slug; returns
// non-URL input unchanged so plain typing still works.
export const extractRepositorySearchTerm = (query: string, provider?: string): string => {
  const trimmed = query.trim();
  if (trimmed === ``) return ``;
  if (REPOSITORY_SLUG_REGEX.test(trimmed)) return trimmed;

  let authority: string | null = null;
  let path: string | null = null;

  const scpMatch = trimmed.match(/^[^/@\s]+@([^/:\s]+):(.+)$/);
  const schemeMatch = trimmed.match(/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\/([^/\s]+)\/(.+)$/);

  if (scpMatch) {
    authority = scpMatch[1];
    path = scpMatch[2];
  } else if (schemeMatch) {
    authority = schemeMatch[1];
    path = schemeMatch[2];
  }

  if (path === null || authority === null) return trimmed;

  // A URL only resolves to a slug when its host is the selected provider's;
  // otherwise leave it as typed so it fails slug validation.
  if (!hostMatchesProvider(authority, provider)) return trimmed;

  path = path.split(/[?#]/)[0].replace(/\/+$/, ``);

  if (provider === `gitlab`) {
    return gitlabProjectPath(path) ?? trimmed;
  }

  // Other providers are always owner/repo; cap at two segments so deep browse
  // URLs (.../tree/main) still resolve.
  const segments = path.split(`/`).filter(Boolean);

  if (segments.length >= 2) {
    const candidate = `${segments[0]}/${segments[1].replace(/\.git$/, ``)}`;
    if (REPOSITORY_SLUG_REGEX.test(candidate)) return candidate;
  }

  return trimmed;
};
