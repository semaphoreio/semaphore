export const REPOSITORY_SLUG_REGEX = /^[A-Za-z0-9][A-Za-z0-9-]*\/[A-Za-z0-9._-]+$/;

export const parseRepositorySlug = (query: string): string | null => {
  const trimmed = query.trim();
  return REPOSITORY_SLUG_REGEX.test(trimmed) ? trimmed : null;
};

const PATH_SEGMENT_REGEX = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;

// Reduces a pasted repository reference to the slug used to match the
// repository list. Accepts web URLs (https://github.com/owner/repo), git/ssh
// URLs (git://host/owner/repo.git, ssh://git@host/owner/repo.git) and scp-like
// remotes (git@host:owner/repo.git), tolerating a trailing ".git", trailing
// slash, query string or fragment. When the input is not a recognizable URL it
// is returned trimmed and unchanged, so plain name typing keeps working.
//
// GitLab namespaces are variable depth (group/subgroup/repo), so for GitLab the
// whole project path is kept — route sub-pages after the "/-/" marker are
// dropped. Other providers cap at the first two segments (owner/repo), so deep
// browse URLs like ".../tree/main" still resolve to the repository.
export const extractRepositorySearchTerm = (query: string, provider?: string): string => {
  const trimmed = query.trim();
  if (trimmed === ``) return ``;
  if (REPOSITORY_SLUG_REGEX.test(trimmed)) return trimmed;

  let path: string | null = null;

  const scpMatch = trimmed.match(/^[^/@\s]+@[^/:\s]+:(.+)$/);
  const schemeMatch = trimmed.match(/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\/[^/\s]+\/(.+)$/);

  if (scpMatch) {
    path = scpMatch[1];
  } else if (schemeMatch) {
    path = schemeMatch[1];
  }

  if (path === null) return trimmed;

  path = path.split(/[?#]/)[0].replace(/\/+$/, ``);

  if (provider === `gitlab`) {
    const segments = path
      .split(`/-/`)[0]
      .replace(/\.git$/, ``)
      .split(`/`)
      .filter(Boolean);

    if (segments.length >= 2 && segments.every((segment) => PATH_SEGMENT_REGEX.test(segment))) {
      return segments.join(`/`);
    }

    return trimmed;
  }

  const segments = path.split(`/`).filter(Boolean);

  if (segments.length >= 2) {
    const candidate = `${segments[0]}/${segments[1].replace(/\.git$/, ``)}`;
    if (REPOSITORY_SLUG_REGEX.test(candidate)) return candidate;
  }

  return trimmed;
};
