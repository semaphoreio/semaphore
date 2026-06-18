export const REPOSITORY_SLUG_REGEX = /^[A-Za-z0-9][A-Za-z0-9-]*\/[A-Za-z0-9._-]+$/;

export const parseRepositorySlug = (query: string): string | null => {
  const trimmed = query.trim();
  return REPOSITORY_SLUG_REGEX.test(trimmed) ? trimmed : null;
};

const PATH_SEGMENT_REGEX = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;

// GitLab namespaces are variable depth; keep the whole path, dropping the "/-/"
// route suffix. Returns null when the path isn't a valid project path.
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
